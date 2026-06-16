import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/user_location.dart';
import '../../domain/repositories/location_repository.dart';

/// Location error codes thrown by this repository.
/// These are plain strings to keep domain layer pure (no Flutter imports).
class LocationError {
  static const String serviceDisabled = 'LOCATION_SERVICE_DISABLED';
  static const String permissionDenied = 'LOCATION_PERMISSION_DENIED';
  static const String permissionDeniedForever = 'LOCATION_PERMISSION_DENIED_FOREVER';
}

/// Real GPS implementation of [LocationRepository] using geolocator package.
/// 
/// Converts geolocator [Position] to domain [UserLocation] in this layer only.
/// 
/// Note: On Web, geolocation may be less reliable but we accept all updates
/// without aggressive filtering for testing purposes.
class LocationRepositoryImpl implements LocationRepository {
  /// Location settings optimized for maximum updates on Web/desktop.
  /// 
  /// - distanceFilter: 0 = receive ALL position updates (no distance threshold)
  /// - accuracy: best available
  /// - No accuracy filtering - we accept all updates regardless of accuracy
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 0, // Accept ALL updates, no minimum distance
  );

  /// Web-specific settings with even more permissive options.
  /// Web geolocation API is less consistent, so we maximize update frequency.
  static final WebSettings _webSettings = WebSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 0,
    maximumAge: const Duration(seconds: 5), // Accept cached positions up to 5s old
  );

  /// Gets platform-appropriate location settings.
  LocationSettings get _settings {
    if (kIsWeb) {
      return _webSettings;
    }
    return _locationSettings;
  }

  /// Ensures location services are enabled and permissions granted.
  /// Throws descriptive error strings on failure.
  Future<void> _ensurePermissions() async {
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationError.serviceDisabled;
    }

    // Check and request permissions
    var permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationError.permissionDenied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationError.permissionDeniedForever;
    }
  }

  @override
  Future<UserLocation> getCurrentLocation() async {
    await _ensurePermissions();

    final position = await Geolocator.getCurrentPosition(
      locationSettings: _settings,
    );

    debugPrint('[LocationRepo] getCurrentLocation: '
        '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)} '
        '(acc: ${position.accuracy.toStringAsFixed(1)}m)');

    return _toUserLocation(position);
  }

  @override
  Stream<UserLocation> watchLocation() async* {
    // Ensure permissions before starting stream
    await _ensurePermissions();

    debugPrint('[LocationRepo] Starting location stream with settings: '
        'accuracy=${_settings.accuracy}, distanceFilter=${_settings.distanceFilter}m, '
        'isWeb=$kIsWeb');

    // Stream ALL position updates without filtering
    // Let the mission engine decide what to do with each update
    yield* Geolocator.getPositionStream(
      locationSettings: _settings,
    ).map((position) {
      debugPrint('[LocationRepo] Stream update: '
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)} '
          '(acc: ${position.accuracy.toStringAsFixed(1)}m)');
      return _toUserLocation(position);
    });
  }

  /// Converts geolocator [Position] to domain [UserLocation].
  /// This conversion happens ONLY in the data layer.
  /// 
  /// NOTE: We do NOT filter by accuracy here. All updates are passed through.
  /// The mission engine or UI can decide how to handle low-accuracy readings.
  UserLocation _toUserLocation(Position position) {
    return UserLocation(
      lat: position.latitude,
      lon: position.longitude,
      accuracyMeters: position.accuracy,
      timestamp: position.timestamp,
    );
  }
}

