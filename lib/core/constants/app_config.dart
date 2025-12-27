import 'package:flutter/foundation.dart';

/// Application configuration and feature flags.
class AppConfig {
  // ============================================================
  // FEATURE FLAGS
  // ============================================================

  /// Whether to use the real RAG backend (true) or mock data (false).
  /// Set to true when the Python backend is running.
  static const bool useRealRagBackend = true;

  /// Whether to use the real AI narration backend (true) or mock (false).
  /// When true, uses /rag/answer endpoint for AI responses.
  static const bool useRealAiBackend = true;

  /// Whether to enable debug logging.
  static const bool enableDebugLogging = true;

  // ============================================================
  // BACKEND URLS
  // ============================================================

  /// RAG backend base URL for desktop/web (localhost).
  static const String _baseUrlDesktop = 'http://127.0.0.1:8000';

  /// RAG backend base URL for Android emulator.
  /// Android emulator uses 10.0.2.2 to reach host machine's localhost.
  static const String _baseUrlAndroidEmulator = 'http://10.0.2.2:8000';

  /// Get the appropriate RAG backend URL based on platform.
  /// 
  /// - Web, Windows, macOS, Linux: use 127.0.0.1
  /// - Android emulator: use 10.0.2.2
  /// - iOS simulator: use 127.0.0.1 (or machine IP for physical device)
  static String get ragBackendUrl {
    // Web always uses localhost
    if (kIsWeb) {
      return _baseUrlDesktop;
    }

    // For non-web platforms, we need to check the OS
    // Note: We can't import dart:io on web, so we use defaultTargetPlatform
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator needs 10.0.2.2 to reach host localhost
        // Physical Android device would need machine's network IP
        return _baseUrlAndroidEmulator;
      case TargetPlatform.iOS:
        // iOS simulator can use localhost
        // Physical iOS device would need machine's network IP
        return _baseUrlDesktop;
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return _baseUrlDesktop;
      default:
        return _baseUrlDesktop;
    }
  }

  // ============================================================
  // AI SETTINGS
  // ============================================================

  /// HTTP request timeout for AI calls.
  static const Duration aiRequestTimeout = Duration(seconds: 15);

  /// Default query when user arrives near target building.
  static const String defaultBuildingInfoQuery =
      'Bu bina hakkında kısa bilgi ver ve giriş/konum yönlendirmesi yap.';

  // ============================================================
  // NAVIGATION SETTINGS
  // ============================================================

  /// Default walking speed in meters per second.
  static const double walkingSpeedMps = 1.2;

  /// Off-route detection threshold in meters.
  static const double offRouteThresholdMeters = 30.0;

  /// Re-route cooldown in seconds.
  static const int reRouteCooldownSeconds = 10;

  /// Nearby building detection threshold in meters.
  static const double nearbyAnchorThresholdMeters = 80.0;

  // ============================================================
  // MAP SETTINGS
  // ============================================================

  /// Default map center (Van Yüzüncü Yıl campus).
  static const double defaultLat = 38.5015;
  static const double defaultLon = 43.3830;
  static const double defaultZoom = 16.0;
}
