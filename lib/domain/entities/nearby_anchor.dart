/// A nearby point of interest (building anchor).
/// 
/// Pure Dart domain entity - no Flutter or map dependencies.
class NearbyAnchor {
  /// Unique identifier of the building/POI.
  final String id;

  /// Human-readable title.
  final String title;

  /// Distance from current position to this anchor, in meters.
  final double distanceMeters;

  const NearbyAnchor({
    required this.id,
    required this.title,
    required this.distanceMeters,
  });

  @override
  String toString() => 'NearbyAnchor($id: ${distanceMeters.toStringAsFixed(0)}m)';
}









