import 'geo_point.dart';

/// A navigation route consisting of geographic points and total distance.
/// 
/// Pure Dart domain entity - no Flutter or map dependencies.
class RoutePath {
  /// Ordered list of points forming the route.
  final List<GeoPoint> points;

  /// Total route distance in meters.
  final double totalMeters;

  const RoutePath({
    required this.points,
    required this.totalMeters,
  });

  /// Whether the route has valid points.
  bool get isValid => points.length >= 2;

  /// Number of points in the route.
  int get length => points.length;

  @override
  String toString() => 'RoutePath(points: ${points.length}, totalMeters: $totalMeters)';
}









