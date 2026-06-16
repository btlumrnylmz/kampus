import 'package:kampus/domain/entities/user_location.dart';

/// Abstract repository for location services.
/// Implementations handle platform-specific GPS access.
abstract class LocationRepository {
  /// Gets current location once.
  Future<UserLocation> getCurrentLocation();

  /// Streams location updates in real-time.
  Stream<UserLocation> watchLocation();
}


