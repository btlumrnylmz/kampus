import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../controllers/map_render_state.dart';
import '../game/widgets/collectible_marker.dart';

/// A map widget displaying campus navigation using OpenStreetMap tiles.
/// 
/// This widget is purely presentational - it renders the [MapRenderState]
/// and does NOT contain any mission logic.
/// 
/// Can be replaced with a Mapbox implementation in the future.
class CampusMapView extends StatefulWidget {
  /// Listenable for map state updates.
  final ValueListenable<MapRenderState> renderState;

  /// Initial center position for the map.
  final LatLng initialCenter;

  /// Initial zoom level.
  final double initialZoom;

  /// Callback when a collectible is tapped.
  final void Function(String collectibleId)? onCollectibleTap;

  /// Optional external map controller (for camera control from parent).
  final MapController? mapController;

  const CampusMapView({
    super.key,
    required this.renderState,
    this.initialCenter = const LatLng(38.5015, 43.3830), // Van Yüzüncü Yıl campus
    this.initialZoom = 16.0,
    this.onCollectibleTap,
    this.mapController,
  });

  @override
  State<CampusMapView> createState() => _CampusMapViewState();
}

class _CampusMapViewState extends State<CampusMapView> {
  late final MapController _mapController;
  LatLng? _lastFollowLocation;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    // Use external controller if provided, otherwise create our own
    if (widget.mapController != null) {
      _mapController = widget.mapController!;
      _ownsController = false;
    } else {
      _mapController = MapController();
      _ownsController = true;
    }
    
    // Listen to render state changes for camera follow
    widget.renderState.addListener(_onRenderStateChanged);
  }

  @override
  void dispose() {
    widget.renderState.removeListener(_onRenderStateChanged);
    // Only dispose if we own the controller
    if (_ownsController) {
      _mapController.dispose();
    }
    super.dispose();
  }

  void _onRenderStateChanged() {
    final state = widget.renderState.value;
    
    // Camera follow mode: smoothly move camera to user location
    if (state.cameraFollowEnabled && state.userLocation != null) {
      final newLocation = state.userLocation!;
      
      // Only move if location changed significantly (avoid jitter)
      if (_lastFollowLocation == null ||
          _distanceBetween(_lastFollowLocation!, newLocation) > 5.0) {
        _lastFollowLocation = newLocation;
        
        // Smooth camera movement
        _mapController.move(
          newLocation,
          _mapController.camera.zoom.clamp(16.0, 18.0), // Zoom in for game mode
        );
      }
    } else {
      _lastFollowLocation = null;
    }
  }

  double _distanceBetween(LatLng a, LatLng b) {
    // Simple distance calculation (approximate)
    final latDiff = (a.latitude - b.latitude).abs();
    final lonDiff = (a.longitude - b.longitude).abs();
    return (latDiff + lonDiff) * 111000; // Rough meters
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MapRenderState>(
      valueListenable: widget.renderState,
      builder: (context, state, _) {
        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: widget.initialZoom,
            minZoom: 10,
            maxZoom: 18,
            // Allow interaction even in follow mode (user can pan to explore)
            // Follow mode just auto-centers, but user can still pan
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            // OpenStreetMap tile layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.kampus.app',
              maxZoom: 19,
            ),

            // Navigation route polyline layer
            if (state.hasRoute)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: state.routePolyline,
                    color: const Color(0xFF4285F4),
                    strokeWidth: 5.0,
                    borderColor: Colors.white,
                    borderStrokeWidth: 2.0,
                  ),
                ],
              ),

            // Collectible markers layer (game mode)
            if (state.collectibles.isNotEmpty)
              MarkerLayer(
                markers: state.collectibles.entries.map((entry) {
                  final isNearby = state.nearbyCollectibleIds.contains(entry.key);
                  return Marker(
                    point: entry.value,
                    width: 40,
                    height: 40,
                    child: CollectibleMarker(
                      id: entry.key,
                      isNearby: isNearby,
                      onTap: widget.onCollectibleTap != null
                          ? () => widget.onCollectibleTap!(entry.key)
                          : null,
                    ),
                  );
                }).toList(),
              ),

            // Markers layer (user + highlight)
            MarkerLayer(
              markers: [
                // User location marker (enhanced for game mode)
                if (state.userLocation != null)
                  Marker(
                    point: state.userLocation!,
                    width: state.cameraFollowEnabled ? 50 : 40,
                    height: state.cameraFollowEnabled ? 50 : 40,
                    child: _UserLocationMarker(
                      isGameMode: state.cameraFollowEnabled,
                    ),
                  ),

                // Highlighted building marker (only show if not in game mode)
                if (state.highlightedPoint != null && !state.cameraFollowEnabled)
                  Marker(
                    point: state.highlightedPoint!,
                    width: 50,
                    height: 50,
                    child: _BuildingMarker(
                      buildingId: state.highlightedBuildingId,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Custom marker for user location with optional game mode glow.
class _UserLocationMarker extends StatefulWidget {
  final bool isGameMode;

  const _UserLocationMarker({this.isGameMode = false});

  @override
  State<_UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<_UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    if (widget.isGameMode) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_UserLocationMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isGameMode && !oldWidget.isGameMode) {
      _controller.repeat(reverse: true);
    } else if (!widget.isGameMode && oldWidget.isGameMode) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGameMode) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing ring
              Container(
                width: 50 + (_pulseAnimation.value * 10),
                height: 50 + (_pulseAnimation.value * 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4285F4)
                          .withValues(alpha: _pulseAnimation.value * 0.6),
                      blurRadius: 15 + (_pulseAnimation.value * 10),
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // Main marker
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4285F4),
                      const Color(0xFF4285F4).withValues(alpha: 0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4285F4)
                          .withValues(alpha: _pulseAnimation.value * 0.8),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    // Regular marker (non-game mode)
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF4285F4),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4285F4).withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

/// Custom marker for highlighted building/target.
class _BuildingMarker extends StatelessWidget {
  final String? buildingId;

  const _BuildingMarker({this.buildingId});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFe94560),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFe94560).withValues(alpha: 0.4),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.flag_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        // Triangle pointer
        CustomPaint(
          size: const Size(12, 8),
          painter: _TrianglePainter(color: const Color(0xFFe94560)),
        ),
      ],
    );
  }
}

/// Paints a downward-pointing triangle for marker pointer.
class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

