import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_config.dart';
import '../../data/datasources/remote/rag_api_client.dart';
import '../../domain/entities/ai_narration_result.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/mission.dart';
import '../../domain/entities/mission_state.dart';
import '../../domain/entities/navigation_instruction.dart';
import '../../domain/entities/nearby_anchor.dart';
import '../../domain/entities/route_path.dart';
import '../../domain/entities/route_status.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/repositories/route_repository.dart';
import '../../domain/usecases/start_mission.dart';
import '../../domain/usecases/update_location.dart';
import '../controllers/map_controller.dart';

/// Provider for mission state management with real GPS tracking and route simulation.
/// 
/// Handles:
/// - Mission initialization and state
/// - Real-time GPS location tracking
/// - Navigation route building and display
/// - Route simulation (DEBUG only)
/// - Map marker updates
/// - AI narration results
/// - AI assistant integration
class MissionProvider extends ChangeNotifier {
  final StartMission startMission;
  final UpdateLocation updateLocation;
  final Mission Function() missionFactory;
  final LocationRepository locationRepository;
  final RouteRepository routeRepository;
  final MapController mapController;
  final Map<String, LatLng> buildingAnchors;
  final RagApiClient? ragApiClient;

  // Mission state
  MissionState? _missionState;
  AiNarrationResult? _aiNarration;
  UserLocation? _lastLocation;
  String? _locationError;
  bool _isTracking = false;
  bool _trackingStarted = false;
  double? _lastDistanceMeters;

  // Navigation route state
  RoutePath? _activeRoute;
  double? _remainingMeters;
  int? _etaMinutes;
  bool _isLoadingRoute = false;
  NavigationInstruction? _currentInstruction;
  int _nearestRouteIndex = 0;

  // Off-route detection state
  RouteStatus _routeStatus = RouteStatus.none;
  DateTime? _lastRerouteTime;
  bool _isRerouting = false;

  // Nearby POI state
  NearbyAnchor? _nearbyAnchor;

  // Route simulation state (DEBUG only)
  Timer? _simulationTimer;
  int _simulationIndex = 0;
  bool _isSimulating = false;

  // AI Assistant state
  bool _aiLoading = false;
  String? _aiError;
  AiNarrationResult? _aiResult;
  String? _lastAiTargetId;

  // Constants
  static const double _walkingSpeedMps = 1.2; // meters per second
  static const Duration _simulationStepInterval = Duration(milliseconds: 800);
  static const double _turnDetectionAngleThreshold = 30.0; // degrees
  static const int _lookAheadPoints = 20; // points to scan for turns
  static const double _offRouteThresholdMeters = 30.0;
  static const int _reRouteCooldownSeconds = 10;
  static const double _nearbyAnchorThresholdMeters = 80.0;

  // GPS subscription
  StreamSubscription<UserLocation>? _locationSubscription;

  // Getters - Mission
  MissionState? get missionState => _missionState;
  AiNarrationResult? get aiNarration => _aiNarration;
  UserLocation? get lastLocation => _lastLocation;
  String? get locationError => _locationError;
  bool get isTracking => _isTracking;
  double? get lastDistanceMeters => _lastDistanceMeters;

  // Getters - Navigation
  RoutePath? get activeRoute => _activeRoute;
  double? get remainingMeters => _remainingMeters;
  int? get etaMinutes => _etaMinutes;
  bool get isLoadingRoute => _isLoadingRoute;
  bool get hasActiveRoute => _activeRoute != null && _activeRoute!.isValid;
  NavigationInstruction? get currentInstruction => _currentInstruction;
  int get nearestRouteIndex => _nearestRouteIndex;

  // Getters - Route Status
  RouteStatus get routeStatus => _routeStatus;
  bool get isOffRoute => _routeStatus.isOffRoute;
  bool get isRerouting => _isRerouting;

  // Getters - Nearby POI
  NearbyAnchor? get nearbyAnchor => _nearbyAnchor;

  // Getters - Simulation (DEBUG)
  bool get isSimulating => _isSimulating;
  int get simulationIndex => _simulationIndex;
  int get simulationTotalPoints => _activeRoute?.length ?? 0;

  // Getters - AI Assistant
  bool get aiLoading => _aiLoading;
  String? get aiError => _aiError;
  AiNarrationResult? get aiResult => _aiResult;
  bool get hasAiResult => _aiResult != null;

  MissionProvider({
    required this.startMission,
    required this.updateLocation,
    required this.missionFactory,
    required this.locationRepository,
    required this.routeRepository,
    required this.mapController,
    required this.buildingAnchors,
    this.ragApiClient,
  });

  /// Initialize mission state.
  Future<void> initMission() async {
    final mission = missionFactory();
    _missionState = await startMission(mission);
    notifyListeners();
  }

  // ============================================================
  // GPS TRACKING
  // ============================================================

  /// Ensures GPS tracking is started only once.
  Future<void> ensureTrackingStarted() async {
    if (_trackingStarted) return;
    _trackingStarted = true;
    await startTracking();
  }

  /// Starts real GPS tracking.
  Future<void> startTracking() async {
    if (_isTracking) return;

    _locationError = null;
    notifyListeners();

    try {
      _isTracking = true;
      notifyListeners();

      _locationSubscription = locationRepository.watchLocation().listen(
        _onLocationUpdate,
        onError: _onLocationError,
        cancelOnError: false,
      );
    } catch (e) {
      _onLocationError(e);
    }
  }

  /// Stops GPS tracking.
  void stopTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _isTracking = false;
    notifyListeners();
  }

  /// Handles incoming location updates (real GPS or simulated).
  Future<void> _onLocationUpdate(UserLocation location) async {
    _lastLocation = location;
    _locationError = null;

    // Update map marker
    mapController.showUserLocation(location);

    // Update remaining distance if route active
    if (_activeRoute != null) {
      _updateRemainingDistance(location);
      // Check off-route status
      await _checkOffRouteStatus(location);
    }

    // Update nearby anchor detection
    _updateNearbyAnchor(location);

    // Process through mission engine
    if (_missionState != null) {
      final target = _missionState!.mission.targetLocation;
      final phaseBefore = _missionState!.phase.name;

      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('[GPS] lat: ${location.lat.toStringAsFixed(6)}, '
          'lon: ${location.lon.toStringAsFixed(6)}, '
          'acc: ${location.accuracyMeters?.toStringAsFixed(1) ?? "?"}m');
      debugPrint('[TARGET] lat: ${target.lat.toStringAsFixed(6)}, '
          'lon: ${target.lon.toStringAsFixed(6)}');
      debugPrint('[PHASE BEFORE] $phaseBefore');

      try {
        final result = await updateLocation(location);
        _lastDistanceMeters = result.distanceMeters;
        _missionState = result.missionState;
        _aiNarration = result.aiNarration;

        debugPrint('[DIST FROM ENGINE] ${_lastDistanceMeters!.toStringAsFixed(2)} meters');
        debugPrint('[PHASE AFTER UPDATE] ${_missionState!.phase.name}');
        debugPrint('═══════════════════════════════════════════════════════════');

        // Check if we should auto-trigger AI when reaching target
        _checkAutoTriggerAi();
      } catch (e) {
        debugPrint('MissionProvider: Mission update error: $e');
        debugPrint('═══════════════════════════════════════════════════════════');
      }
    }

    notifyListeners();
  }

  void _onLocationError(dynamic error) {
    _isTracking = false;
    _locationError = _formatLocationError(error);
    notifyListeners();
  }

  String _formatLocationError(dynamic error) {
    final errorStr = error.toString();
    if (errorStr.contains('LOCATION_SERVICE_DISABLED')) {
      return 'Konum servisi kapalı. Lütfen GPS\'i açın.';
    } else if (errorStr.contains('LOCATION_PERMISSION_DENIED_FOREVER')) {
      return 'Konum izni kalıcı olarak reddedildi. Ayarlardan izin verin.';
    } else if (errorStr.contains('LOCATION_PERMISSION_DENIED')) {
      return 'Konum izni reddedildi. Lütfen izin verin.';
    } else {
      return 'Konum alınamadı: $errorStr';
    }
  }

  // ============================================================
  // AI ASSISTANT
  // ============================================================

  /// Check if we should auto-trigger AI when mission phase changes to nearTarget.
  void _checkAutoTriggerAi() {
    if (_missionState == null) return;
    if (ragApiClient == null) return;

    final targetId = _missionState!.mission.targetBuildingId;
    final isNearTarget = _missionState!.phase == MissionPhase.nearTarget;

    // Auto-trigger AI when:
    // - Phase is nearTarget
    // - We haven't already asked for this target
    if (isNearTarget && _lastAiTargetId != targetId) {
      debugPrint('[AI] Auto-triggering AI for target: $targetId');
      _lastAiTargetId = targetId;
      
      // Use default query for building info
      askAssistant(AppConfig.defaultBuildingInfoQuery);
    }
  }

  /// Ask the AI assistant a question.
  Future<void> askAssistant(String userQuery) async {
    if (ragApiClient == null) {
      _aiError = 'AI backend bağlantısı yapılandırılmamış.';
      _aiResult = AiNarrationResult.error(_aiError!);
      notifyListeners();
      return;
    }

    _aiLoading = true;
    _aiError = null;
    notifyListeners();

    try {
      debugPrint('[AI] Asking: $userQuery');

      // Build request payload
      final request = AnswerRequestDto(
        query: userQuery,
        gps: _lastLocation != null
            ? GpsDto(
                lat: _lastLocation!.lat,
                lon: _lastLocation!.lon,
                accuracyM: _lastLocation!.accuracyMeters,
              )
            : null,
        missionState: _missionState != null
            ? MissionStateDto(
                missionId: _missionState!.mission.id,
                phase: _missionState!.phase.name,
                targetId: _missionState!.mission.targetBuildingId,
              )
            : null,
        nearbyAnchorId: _nearbyAnchor?.id ?? _missionState?.mission.targetBuildingId,
      );

      final response = await ragApiClient!.answer(request);

      // Map response to domain entity
      _aiResult = _mapAnswerResponse(response);
      _aiError = null;

      debugPrint('[AI] Response status: ${response.status}');
      if (response.answer != null) {
        debugPrint('[AI] Answer: ${response.answer!.substring(0, response.answer!.length.clamp(0, 100))}...');
      }
    } catch (e) {
      debugPrint('[AI] Error: $e');
      _aiError = 'Bağlantı hatası: $e';
      _aiResult = AiNarrationResult.error(_aiError!);
    } finally {
      _aiLoading = false;
      notifyListeners();
    }
  }

  /// Map API response to domain entity.
  AiNarrationResult _mapAnswerResponse(AnswerResponseDto response) {
    AiNarrationStatus status;
    switch (response.status) {
      case 'ok':
        status = AiNarrationStatus.ok;
        break;
      case 'no_answer':
        status = AiNarrationStatus.noAnswer;
        break;
      case 'out_of_scope':
        status = AiNarrationStatus.outOfScope;
        break;
      case 'rejected':
        status = AiNarrationStatus.rejected;
        break;
      default:
        status = AiNarrationStatus.error;
    }

    return AiNarrationResult(
      status: status,
      missionExplanation: response.answer,
      reasoning: response.contextUsed != null ? [response.contextUsed!] : [],
      nextActions: response.actions,
      sources: response.sources.map((s) => s.sourceId).toList(),
      message: response.message,
      suggestions: response.suggestions,
      confidence: response.confidence,
      modelUsed: response.modelUsed,
      latencyMs: response.meta.latencyMs,
      modelName: response.meta.model,
    );
  }

  /// Clear AI result.
  void clearAiResult() {
    _aiResult = null;
    _aiError = null;
    notifyListeners();
  }

  // ============================================================
  // NAVIGATION ROUTE
  // ============================================================

  /// Builds a navigation route from current location to mission target.
  Future<void> buildRouteToTarget() async {
    if (_missionState == null) {
      debugPrint('[Route] No active mission');
      return;
    }

    // Use last known location or a default start point
    final from = _lastLocation != null
        ? GeoPoint(lat: _lastLocation!.lat, lon: _lastLocation!.lon)
        : GeoPoint(
            lat: _missionState!.mission.targetLocation.lat + 0.005,
            lon: _missionState!.mission.targetLocation.lon + 0.005,
          );

    final to = GeoPoint(
      lat: _missionState!.mission.targetLocation.lat,
      lon: _missionState!.mission.targetLocation.lon,
    );

    _isLoadingRoute = true;
    notifyListeners();

    try {
      debugPrint('[Route] Building route from ($from) to ($to)');
      _activeRoute = await routeRepository.buildRoute(from: from, to: to);

      // Push polyline to map
      mapController.setRoutePolyline(_activeRoute!.points);

      // Initialize remaining distance
      _remainingMeters = _activeRoute!.totalMeters;
      _etaMinutes = (_remainingMeters! / _walkingSpeedMps / 60).ceil();

      // Reset simulation
      _simulationIndex = 0;

      debugPrint('[Route] Route built: ${_activeRoute!.length} points, '
          '${_activeRoute!.totalMeters.toStringAsFixed(0)}m');
    } catch (e) {
      debugPrint('[Route] Failed to build route: $e');
    } finally {
      _isLoadingRoute = false;
      notifyListeners();
    }
  }

  /// Clears the active navigation route.
  void clearRoute() {
    _activeRoute = null;
    _remainingMeters = null;
    _etaMinutes = null;
    _currentInstruction = null;
    _nearestRouteIndex = 0;
    _simulationIndex = 0;
    _routeStatus = RouteStatus.none;
    _isRerouting = false;
    mapController.clearRoute();
    notifyListeners();
  }

  /// Updates remaining distance and navigation instruction based on current location.
  void _updateRemainingDistance(UserLocation location) {
    if (_activeRoute == null || !_activeRoute!.isValid) return;

    final points = _activeRoute!.points;

    // Find nearest point on route
    int nearestIndex = 0;
    double nearestDist = double.infinity;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final dist = _haversineDistance(location.lat, location.lon, point.lat, point.lon);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestIndex = i;
      }
    }

    _nearestRouteIndex = nearestIndex;

    // Sum remaining segment lengths
    double remaining = 0;
    for (int i = nearestIndex; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      remaining += _haversineDistance(p1.lat, p1.lon, p2.lat, p2.lon);
    }

    _remainingMeters = remaining;
    _etaMinutes = (_remainingMeters! / _walkingSpeedMps / 60).ceil();

    // Compute navigation instruction
    _currentInstruction = _computeNextInstruction(nearestIndex, remaining);
  }

  /// Computes the next turn-by-turn navigation instruction.
  NavigationInstruction _computeNextInstruction(int currentIndex, double remainingMeters) {
    final points = _activeRoute!.points;
    final proximityThreshold = _missionState?.mission.constraints.proximityMeters ?? 50;

    // Check if we've arrived
    if (remainingMeters <= proximityThreshold) {
      return NavigationInstruction.arrive();
    }

    // Need at least 3 points to detect a turn
    if (points.length < 3 || currentIndex >= points.length - 2) {
      return NavigationInstruction.straight(distanceMeters: remainingMeters);
    }

    // Scan ahead for the next significant turn
    final maxLookAhead = math.min(currentIndex + _lookAheadPoints, points.length - 1);

    for (int i = currentIndex; i < maxLookAhead - 1; i++) {
      // We need 3 consecutive points to compute bearing change
      if (i + 2 >= points.length) break;

      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = points[i + 2];

      // Compute bearings
      final bearing1 = _computeBearing(p1, p2);
      final bearing2 = _computeBearing(p2, p3);

      // Compute bearing change (normalized to -180 to 180)
      double bearingChange = bearing2 - bearing1;
      if (bearingChange > 180) bearingChange -= 360;
      if (bearingChange < -180) bearingChange += 360;

      // Check if this is a significant turn
      if (bearingChange.abs() >= _turnDetectionAngleThreshold) {
        // Compute distance from current position to this turn point
        double distanceToTurn = 0;
        for (int j = currentIndex; j <= i + 1 && j < points.length - 1; j++) {
          final a = points[j];
          final b = points[j + 1];
          distanceToTurn += _haversineDistance(a.lat, a.lon, b.lat, b.lon);
        }

        debugPrint('[Nav] Turn detected at index ${i + 1}: '
            'bearing change ${bearingChange.toStringAsFixed(1)}°, '
            'distance ${distanceToTurn.toStringAsFixed(0)}m');

        return NavigationInstruction.fromBearingChange(
          bearingChange: bearingChange,
          distanceMeters: distanceToTurn,
        );
      }
    }

    // No turn found in look-ahead range - go straight
    // Use distance to end of look-ahead or remaining distance
    double straightDistance = 0;
    for (int i = currentIndex; i < maxLookAhead - 1 && i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      straightDistance += _haversineDistance(p1.lat, p1.lon, p2.lat, p2.lon);
    }

    return NavigationInstruction.straight(
      distanceMeters: math.min(straightDistance, remainingMeters),
    );
  }

  /// Computes bearing (azimuth) from point a to point b in degrees (0-360).
  double _computeBearing(GeoPoint a, GeoPoint b) {
    final lat1 = _toRad(a.lat);
    final lat2 = _toRad(b.lat);
    final dLon = _toRad(b.lon - a.lon);

    final x = math.sin(dLon) * math.cos(lat2);
    final y = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearing = math.atan2(x, y);
    return (bearing * 180 / math.pi + 360) % 360;
  }

  // ============================================================
  // OFF-ROUTE DETECTION
  // ============================================================

  /// Checks if user has deviated from the route and triggers re-route if needed.
  Future<void> _checkOffRouteStatus(UserLocation location) async {
    if (_activeRoute == null || !_activeRoute!.isValid) {
      _routeStatus = RouteStatus.none;
      return;
    }

    // Compute minimum distance from current location to route polyline
    final distanceToRoute = _computeDistanceToPolyline(
      location.lat,
      location.lon,
      _activeRoute!.points,
    );

    debugPrint('[Route] distanceToRoute=${distanceToRoute.toStringAsFixed(1)}m '
        'offRoute=${distanceToRoute > _offRouteThresholdMeters}');

    if (distanceToRoute > _offRouteThresholdMeters) {
      // User is off-route
      final now = DateTime.now();
      final canReroute = _lastRerouteTime == null ||
          now.difference(_lastRerouteTime!).inSeconds >= _reRouteCooldownSeconds;

      if (canReroute && !_isRerouting) {
        debugPrint('[Route] distanceToRoute=${distanceToRoute.toStringAsFixed(1)}m '
            'offRoute=true -> reroute');
        
        _routeStatus = RouteStatus.offRoute(
          distanceMeters: distanceToRoute,
          isRerouting: true,
        );
        _isRerouting = true;
        notifyListeners();

        // Trigger re-route
        _lastRerouteTime = now;
        await buildRouteToTarget();

        _isRerouting = false;
        _routeStatus = RouteStatus.onRoute(distanceMeters: 0);
      } else {
        _routeStatus = RouteStatus.offRoute(
          distanceMeters: distanceToRoute,
          isRerouting: _isRerouting,
        );
      }
    } else {
      // User is on route
      _routeStatus = RouteStatus.onRoute(distanceMeters: distanceToRoute);
    }
  }

  /// Computes minimum distance from a point to a polyline (list of GeoPoints).
  /// Uses point-to-segment distance for each segment.
  double _computeDistanceToPolyline(double lat, double lon, List<GeoPoint> polyline) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1) {
      return _haversineDistance(lat, lon, polyline[0].lat, polyline[0].lon);
    }

    double minDistance = double.infinity;

    for (int i = 0; i < polyline.length - 1; i++) {
      final p1 = polyline[i];
      final p2 = polyline[i + 1];

      final dist = _pointToSegmentDistance(lat, lon, p1.lat, p1.lon, p2.lat, p2.lon);
      if (dist < minDistance) {
        minDistance = dist;
      }
    }

    return minDistance;
  }

  /// Computes distance from point (lat, lon) to line segment (lat1,lon1)-(lat2,lon2).
  /// Uses equirectangular approximation for short distances.
  double _pointToSegmentDistance(
    double lat,
    double lon,
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Convert to approximate meters using equirectangular projection
    // This is accurate enough for short distances (< 1km)
    final cosLat = math.cos(_toRad((lat1 + lat2) / 2));
    
    // Convert to local Cartesian coordinates (meters)
    const metersPerDegLat = 111320.0; // approximate
    final metersPerDegLon = 111320.0 * cosLat;

    final px = (lon - lon1) * metersPerDegLon;
    final py = (lat - lat1) * metersPerDegLat;
    final ax = (lon2 - lon1) * metersPerDegLon;
    final ay = (lat2 - lat1) * metersPerDegLat;

    // Compute projection of point onto line segment
    final segmentLengthSq = ax * ax + ay * ay;
    
    if (segmentLengthSq == 0) {
      // Segment is a point
      return math.sqrt(px * px + py * py);
    }

    // Parameter t of projection onto infinite line
    var t = (px * ax + py * ay) / segmentLengthSq;
    
    // Clamp to segment
    t = t.clamp(0.0, 1.0);

    // Closest point on segment
    final closestX = t * ax;
    final closestY = t * ay;

    // Distance from point to closest point on segment
    final dx = px - closestX;
    final dy = py - closestY;

    return math.sqrt(dx * dx + dy * dy);
  }

  // ============================================================
  // NEARBY BUILDING DETECTION
  // ============================================================

  /// Updates the nearby anchor based on current location.
  void _updateNearbyAnchor(UserLocation location) {
    if (buildingAnchors.isEmpty) {
      _nearbyAnchor = null;
      return;
    }

    String? nearestId;
    double nearestDistance = double.infinity;

    for (final entry in buildingAnchors.entries) {
      final anchor = entry.value;
      final dist = _haversineDistance(
        location.lat,
        location.lon,
        anchor.latitude,
        anchor.longitude,
      );

      if (dist < nearestDistance) {
        nearestDistance = dist;
        nearestId = entry.key;
      }
    }

    if (nearestId != null && nearestDistance <= _nearbyAnchorThresholdMeters) {
      // Format title from ID (e.g., "central_library" -> "Central Library")
      final title = _formatBuildingTitle(nearestId);
      
      _nearbyAnchor = NearbyAnchor(
        id: nearestId,
        title: title,
        distanceMeters: nearestDistance,
      );

      debugPrint('[Nearby] nearest=$nearestId dist=${nearestDistance.toStringAsFixed(0)}m');
    } else {
      _nearbyAnchor = null;
    }
  }

  /// Formats a building ID into a human-readable title.
  String _formatBuildingTitle(String id) {
    // Convert snake_case to Title Case
    return id
        .split('_')
        .map((word) => word.isEmpty 
            ? '' 
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  // ============================================================
  // ROUTE SIMULATION (DEBUG ONLY)
  // ============================================================

  /// DEBUG: Starts automatic route simulation.
  /// Moves through route points and processes each as a location update.
  void startRouteSimulation() {
    if (!kDebugMode) return;
    if (_activeRoute == null || !_activeRoute!.isValid) {
      debugPrint('[Simulation] No active route to simulate');
      return;
    }
    if (_isSimulating) return;

    _isSimulating = true;
    _simulationIndex = 0;
    debugPrint('[Simulation] Starting route simulation: ${_activeRoute!.length} points');

    _simulationTimer = Timer.periodic(_simulationStepInterval, (_) {
      _stepSimulation();
    });

    notifyListeners();
  }

  /// DEBUG: Stops route simulation.
  void stopRouteSimulation() {
    if (!kDebugMode) return;

    _simulationTimer?.cancel();
    _simulationTimer = null;
    _isSimulating = false;
    debugPrint('[Simulation] Stopped');
    notifyListeners();
  }

  /// DEBUG: Steps simulation forward once.
  void stepSimulationOnce() {
    if (!kDebugMode) return;
    if (_activeRoute == null || !_activeRoute!.isValid) return;

    _stepSimulation();
  }

  void _stepSimulation() {
    if (_activeRoute == null || _simulationIndex >= _activeRoute!.length) {
      stopRouteSimulation();
      debugPrint('[Simulation] Completed');
      return;
    }

    final point = _activeRoute!.points[_simulationIndex];
    final simulatedLocation = UserLocation(
      lat: point.lat,
      lon: point.lon,
      accuracyMeters: 5,
      timestamp: DateTime.now(),
    );

    debugPrint('[Simulation] Step ${_simulationIndex + 1}/${_activeRoute!.length}: '
        '(${point.lat.toStringAsFixed(6)}, ${point.lon.toStringAsFixed(6)})');

    // Process through same pipeline as real GPS
    _onLocationUpdate(simulatedLocation);

    _simulationIndex++;
    notifyListeners();
  }

  // ============================================================
  // LEGACY DEBUG
  // ============================================================

  /// DEBUG: Simulates instant movement to target.
  Future<void> simulateMovement() async {
    if (_missionState == null) return;

    final mockLocation = UserLocation(
      lat: _missionState!.mission.targetLocation.lat + 0.00001,
      lon: _missionState!.mission.targetLocation.lon + 0.00001,
      accuracyMeters: 3,
      timestamp: DateTime.now(),
    );

    await _onLocationUpdate(mockLocation);
  }

  /// DEBUG: Simulates going off-route by offsetting position significantly.
  Future<void> simulateOffRoute() async {
    if (!kDebugMode) return;
    if (_lastLocation == null && _activeRoute == null) return;

    // Offset position by ~50m perpendicular to route
    final baseLat = _lastLocation?.lat ?? _activeRoute!.points.first.lat;
    final baseLon = _lastLocation?.lon ?? _activeRoute!.points.first.lon;

    final offRouteLocation = UserLocation(
      lat: baseLat + 0.0005, // ~55m north
      lon: baseLon + 0.0005, // ~55m east (at equator, less at higher latitudes)
      accuracyMeters: 5,
      timestamp: DateTime.now(),
    );

    debugPrint('[Simulation] Simulating off-route position');
    await _onLocationUpdate(offRouteLocation);
  }

  // ============================================================
  // UTILITIES
  // ============================================================

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRad(double deg) => deg * (math.pi / 180.0);

  @override
  void dispose() {
    stopTracking();
    stopRouteSimulation();
    super.dispose();
  }
}
