import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Service for handling location permissions and GPS streams.
/// 
/// Provides:
/// - Permission checking and requesting
/// - Current location retrieval
/// - Location stream for real-time tracking
class LocationService {
  /// Check if location services are enabled.
  Future<bool> isLocationEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check location permission status.
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission.
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Get current location with high accuracy.
  /// 
  /// Returns null if permission denied or location unavailable.
  Future<LatLng?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      final isEnabled = await isLocationEnabled();
      if (!isEnabled) {
        return null;
      }

      // Check and request permission
      LocationPermission permission = await checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      return null;
    }
  }

  /// Watch location changes as a stream.
  /// 
  /// Emits LatLng updates as the user moves.
  /// Uses high accuracy and minimal distance filter for game mode.
  Stream<LatLng> watchLocation() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).map((position) => LatLng(position.latitude, position.longitude));
  }
}


