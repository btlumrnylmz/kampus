import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'campus_locations.dart';

/// YYÜ Kampüs Haritası — Optimize edilmiş versiyon
class CampusMapScreen extends StatefulWidget {
  final CampusLocation? focusLocation;
  const CampusMapScreen({super.key, this.focusLocation});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  bool _loadingLocation = false;
  String _selectedCategory = 'Tümü';
  CampusLocation? _selectedLocation;

  // Rota
  List<LatLng> _routePoints = [];
  double? _routeDistanceKm;
  double? _routeDurationMin;
  bool _loadingRoute = false;

  // Marker cache
  List<Marker>? _cachedMarkers;
  String? _cacheKey;

  @override
  void initState() {
    super.initState();
    if (widget.focusLocation != null) {
      _selectedLocation = widget.focusLocation;
      _autoNavigate();
    }
  }

  Future<void> _autoNavigate() async {
    await _getUserLocation();
    if (_userLocation != null && _selectedLocation != null) {
      _getRoute(_userLocation!, _selectedLocation!.coordinates);
    }
  }

  Future<void> _getUserLocation() async {
    if (_loadingLocation) return;
    setState(() => _loadingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Konum izni reddedildi');
          setState(() => _loadingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Konum izni kalıcı olarak reddedildi.');
        setState(() => _loadingLocation = false);
        return;
      }

      // Daha hızlı konum: medium accuracy
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final newLoc = LatLng(position.latitude, position.longitude);

      setState(() {
        _userLocation = newLoc;
        _loadingLocation = false;
        _invalidateMarkerCache();
      });

      if (_selectedLocation != null) {
        _getRoute(newLoc, _selectedLocation!.coordinates);
      } else {
        _mapController.move(newLoc, 16.0);
      }
      _showSnackBar('Konumunuz bulundu!');
    } catch (e) {
      setState(() => _loadingLocation = false);
      _showSnackBar('Konum alınamadı');
    }
  }

  /// OSRM rota — fire-and-forget, UI bloklamaz
  Future<void> _getRoute(LatLng from, LatLng to) async {
    setState(() => _loadingRoute = true);

    try {
      final url =
          'https://router.project-osrm.org/route/v1/foot/'
          '${from.longitude},${from.latitude};'
          '${to.longitude},${to.latitude}'
          '?overview=full&geometries=geojson';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final coords = route['geometry']['coordinates'] as List;

          setState(() {
            _routePoints = coords
                .map<LatLng>(
                  (c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ),
                )
                .toList();
            _routeDistanceKm = (route['distance'] as num).toDouble() / 1000.0;
            // OSRM foot profili gerçekçi değil, mesafeden hesapla (~4.5 km/h yaya hızı)
            _routeDurationMin = (route['distance'] as num).toDouble() / 75.0;
            _loadingRoute = false;
          });
          _fitRouteBounds();
          return;
        }
      }
      _fallbackRoute(from, to);
    } catch (_) {
      if (mounted) _fallbackRoute(from, to);
    }
  }

  void _fallbackRoute(LatLng from, LatLng to) {
    final dist = _selectedLocation?.distanceTo(from) ?? 0;
    setState(() {
      _routePoints = [from, to];
      _routeDistanceKm = dist / 1000.0;
      _routeDurationMin = (dist / 83.33); // ~5 km/h
      _loadingRoute = false;
    });
    _fitRouteBounds();
  }

  void _fitRouteBounds() {
    if (_routePoints.isEmpty) return;
    final allPts = [..._routePoints];
    if (_userLocation != null) allPts.add(_userLocation!);

    double minLat = allPts.first.latitude, maxLat = minLat;
    double minLng = allPts.first.longitude, maxLng = minLng;
    for (final p in allPts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat - 0.002, minLng - 0.002),
          LatLng(maxLat + 0.002, maxLng + 0.002),
        ),
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ============ MARKER CACHE ============

  void _invalidateMarkerCache() => _cacheKey = null;

  String _computeCacheKey() {
    return '$_selectedCategory|${_selectedLocation?.name}|${_userLocation?.latitude}';
  }

  List<CampusLocation> get _filteredLocations {
    if (_selectedCategory == 'Tümü') return campusLocations;
    return campusLocations
        .where((l) => l.category == _selectedCategory)
        .toList();
  }

  List<Marker> _getMarkers() {
    final key = _computeCacheKey();
    if (_cachedMarkers != null && _cacheKey == key) return _cachedMarkers!;

    final markers = <Marker>[];
    for (final loc in _filteredLocations) {
      final sel = _selectedLocation == loc;
      markers.add(
        Marker(
          point: loc.coordinates,
          width: sel ? 48 : 38,
          height: sel ? 48 : 38,
          child: GestureDetector(
            onTap: () => _onMarkerTap(loc),
            child: _MarkerIcon(loc: loc, selected: sel),
          ),
        ),
      );
    }

    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 30,
          height: 30,
          child: const _UserLocationDot(),
        ),
      );
    }

    _cachedMarkers = markers;
    _cacheKey = key;
    return markers;
  }

  void _onMarkerTap(CampusLocation loc) {
    setState(() {
      _selectedLocation = loc;
      _routePoints = [];
      _routeDistanceKm = null;
      _routeDurationMin = null;
      _invalidateMarkerCache();
    });

    if (_userLocation != null) {
      _getRoute(_userLocation!, loc.coordinates);
    }
    _mapController.move(loc.coordinates, 17.0);
  }

  // ============ BUILD ============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kampüs Haritası'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            onPressed: _loadingLocation ? null : _getUserLocation,
            icon: _loadingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.my_location),
            tooltip: 'Konumumu Bul',
          ),
          IconButton(
            onPressed: () => _mapController.move(kampusMerkez, 15.5),
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Kampüs Merkezi',
          ),
        ],
      ),
      body: Column(
        children: [
          _CategoryFilterBar(
            selected: _selectedCategory,
            onSelect: (cat) => setState(() {
              _selectedCategory = cat;
              _selectedLocation = null;
              _routePoints = [];
              _invalidateMarkerCache();
            }),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        widget.focusLocation?.coordinates ?? kampusMerkez,
                    initialZoom: widget.focusLocation != null ? 17.0 : 15.5,
                    minZoom: 13.0,
                    maxZoom: 19.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.yyu.kampusdanismani',
                      tileProvider: NetworkTileProvider(),
                    ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 5,
                            color: Colors.blue.shade700,
                          ),
                        ],
                      ),
                    MarkerLayer(markers: _getMarkers()),
                  ],
                ),
                if (_loadingRoute)
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Rota hesaplanıyor...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_selectedLocation != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _LocationInfoCard(
                      loc: _selectedLocation!,
                      routeDistanceKm: _routeDistanceKm,
                      routeDurationMin: _routeDurationMin,
                      userLocation: _userLocation,
                      onClose: () => setState(() {
                        _selectedLocation = null;
                        _routePoints = [];
                        _routeDistanceKm = null;
                        _routeDurationMin = null;
                        _invalidateMarkerCache();
                      }),
                      onGetRoute: () => _getRoute(
                        _userLocation!,
                        _selectedLocation!.coordinates,
                      ),
                      onGetLocation: _getUserLocation,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showLocationList,
        backgroundColor: const Color(0xFF003366),
        child: const Icon(Icons.list, color: Colors.white),
      ),
    );
  }

  void _showLocationList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, sc) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Kampüs Lokasyonları',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: sc,
                itemCount: _filteredLocations.length,
                itemBuilder: (_, i) {
                  final loc = _filteredLocations[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: loc.color.withValues(alpha: 0.15),
                      child: Icon(loc.icon, color: loc.color, size: 20),
                    ),
                    title: Text(
                      loc.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _userLocation != null
                          ? '${loc.category} • ${loc.formattedDistanceTo(_userLocation!)}'
                          : loc.category,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(ctx);
                      _onMarkerTap(loc);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ EXTRACTED WIDGETS (const-friendly, no rebuilds) ============

/// Marker ikonu — ayrı widget = gereksiz rebuild önler
class _MarkerIcon extends StatelessWidget {
  final CampusLocation loc;
  final bool selected;
  const _MarkerIcon({required this.loc, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? loc.color : loc.color.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.white : Colors.white70,
          width: selected ? 3 : 2,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: loc.color.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Icon(loc.icon, color: Colors.white, size: selected ? 22 : 18),
    );
  }
}

/// Kullanıcı konumu noktası
class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(Icons.person_pin, color: Colors.white, size: 16),
    );
  }
}

/// Kategori filtre çubuğu
class _CategoryFilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _CategoryFilterBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cats = ['Tümü', ...getAllCategories()];
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: cats.length,
        itemBuilder: (_, i) {
          final c = cats[i];
          final isSel = selected == c;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                c,
                style: TextStyle(
                  fontSize: 12,
                  color: isSel ? Colors.white : Colors.black87,
                ),
              ),
              selected: isSel,
              selectedColor: const Color(0xFF003366),
              checkmarkColor: Colors.white,
              onSelected: (_) => onSelect(c),
            ),
          );
        },
      ),
    );
  }
}

/// Lokasyon bilgi kartı
class _LocationInfoCard extends StatelessWidget {
  final CampusLocation loc;
  final double? routeDistanceKm;
  final double? routeDurationMin;
  final LatLng? userLocation;
  final VoidCallback onClose;
  final VoidCallback onGetRoute;
  final VoidCallback onGetLocation;

  const _LocationInfoCard({
    required this.loc,
    this.routeDistanceKm,
    this.routeDurationMin,
    this.userLocation,
    required this.onClose,
    required this.onGetRoute,
    required this.onGetLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: loc.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(loc.icon, color: loc.color, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        loc.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: loc.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              loc.description,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),

            if (routeDistanceKm != null && routeDurationMin != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.green.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Icon(
                            Icons.straighten,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            routeDistanceKm! < 1
                                ? '${(routeDistanceKm! * 1000).round()} m'
                                : '${routeDistanceKm!.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          Text(
                            'Mesafe',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade300,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Icon(
                            Icons.directions_walk,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            routeDurationMin! < 1
                                ? '< 1 dk'
                                : '${routeDurationMin!.round()} dk',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            'Yürüyüş',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (userLocation != null && routeDistanceKm == null) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: onGetRoute,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.route, color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Rota çiz (${loc.formattedDistanceTo(userLocation!)})',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (userLocation == null) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: onGetLocation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.my_location,
                        color: Colors.orange.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Konumu aç ve mesafeyi gör',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
