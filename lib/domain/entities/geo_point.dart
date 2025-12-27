/// A geographic point with latitude and longitude.
/// 
/// Pure Dart domain entity - no Flutter or map dependencies.
class GeoPoint {
  final double lat;
  final double lon;

  const GeoPoint({
    required this.lat,
    required this.lon,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lon == other.lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'GeoPoint(lat: $lat, lon: $lon)';
}









