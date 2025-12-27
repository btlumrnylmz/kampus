import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/geo_point.dart';
import '../../domain/entities/route_path.dart';
import '../../domain/repositories/route_repository.dart';

/// Implementation of [RouteRepository] using OSRM public API with fallback.
/// 
/// Primary: OSRM routing API (free, no key required)
/// Fallback: Straight-line interpolated route
class RouteRepositoryImpl implements RouteRepository {
  /// OSRM public routing endpoint
  static const String _osrmBaseUrl = 'https://router.project-osrm.org';

  /// Number of interpolated points for fallback straight-line route
  static const int _fallbackInterpolationPoints = 20;

  /// HTTP client (injectable for testing)
  final http.Client _client;

  RouteRepositoryImpl({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<RoutePath> buildRoute({
    required GeoPoint from,
    required GeoPoint to,
  }) async {
    debugPrint('[RouteRepository] Building route from '
        '(${from.lat.toStringAsFixed(6)}, ${from.lon.toStringAsFixed(6)}) to '
        '(${to.lat.toStringAsFixed(6)}, ${to.lon.toStringAsFixed(6)})');

    try {
      return await _fetchOsrmRoute(from, to);
    } catch (e) {
      debugPrint('[RouteRepository] OSRM failed: $e, using fallback');
      return _buildFallbackRoute(from, to);
    }
  }

  /// Fetches route from OSRM API.
  /// 
  /// OSRM URL format: /route/v1/driving/{lon1},{lat1};{lon2},{lat2}?overview=full&geometries=geojson
  /// Note: OSRM uses lon,lat order (not lat,lon)!
  Future<RoutePath> _fetchOsrmRoute(GeoPoint from, GeoPoint to) async {
    final url = Uri.parse(
      '$_osrmBaseUrl/route/v1/walking/'
      '${from.lon},${from.lat};${to.lon},${to.lat}'
      '?overview=full&geometries=geojson',
    );

    debugPrint('[RouteRepository] OSRM request: $url');

    final response = await _client.get(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('OSRM request timeout'),
    );

    if (response.statusCode != 200) {
      throw Exception('OSRM returned ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    
    if (json['code'] != 'Ok') {
      throw Exception('OSRM error: ${json['code']}');
    }

    final routes = json['routes'] as List<dynamic>;
    if (routes.isEmpty) {
      throw Exception('OSRM returned no routes');
    }

    final route = routes[0] as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;
    final distance = (route['distance'] as num).toDouble(); // meters

    // Parse GeoJSON coordinates [lon, lat] -> GeoPoint(lat, lon)
    final points = coordinates.map((coord) {
      final c = coord as List<dynamic>;
      final lon = (c[0] as num).toDouble();
      final lat = (c[1] as num).toDouble();
      return GeoPoint(lat: lat, lon: lon);
    }).toList();

    debugPrint('[RouteRepository] OSRM route: ${points.length} points, $distance meters');

    return RoutePath(points: points, totalMeters: distance);
  }

  /// Builds a fallback straight-line route with interpolated points.
  RoutePath _buildFallbackRoute(GeoPoint from, GeoPoint to) {
    final points = <GeoPoint>[];
    
    // Interpolate points along the straight line
    for (int i = 0; i <= _fallbackInterpolationPoints; i++) {
      final t = i / _fallbackInterpolationPoints;
      final lat = from.lat + (to.lat - from.lat) * t;
      final lon = from.lon + (to.lon - from.lon) * t;
      points.add(GeoPoint(lat: lat, lon: lon));
    }

    // Calculate straight-line distance
    final totalMeters = _haversineDistance(from.lat, from.lon, to.lat, to.lon);

    debugPrint('[RouteRepository] Fallback route: ${points.length} points, '
        '${totalMeters.toStringAsFixed(1)} meters (straight line)');

    return RoutePath(points: points, totalMeters: totalMeters);
  }

  /// Haversine formula to calculate distance in meters.
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0; // meters
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRad(double deg) => deg * (math.pi / 180.0);
}









