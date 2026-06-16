class UserLocation {
  final double lat;
  final double lon;
  final double? accuracyMeters;
  final DateTime timestamp;

  const UserLocation({
    required this.lat,
    required this.lon,
    this.accuracyMeters,
    required this.timestamp,
  });
}


