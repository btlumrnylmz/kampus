import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:kampus/domain/entities/mission_state.dart';
import 'package:kampus/domain/entities/simulation_event.dart';
import 'package:kampus/domain/entities/user_location.dart';
import 'package:kampus/domain/repositories/simulation_repository.dart';

class MockSimulationRepository implements SimulationRepository {
  final double targetLat;
  final double targetLon;
  final int successPoints;

  const MockSimulationRepository({
    required this.targetLat,
    required this.targetLon,
    this.successPoints = 100,
  });

  @override
  Future<SimulationResult> evaluate({
    required UserLocation location,
    required MissionState current,
  }) async {
    // Use mission's target location (not constructor params) for consistency
    final missionTarget = current.mission.targetLocation;
    final proximityThreshold = current.mission.constraints.proximityMeters;

    // Calculate distance in METERS using haversine formula
    // Order: (location.lat, location.lon, target.lat, target.lon)
    final distanceMeters = _haversineDistanceMeters(
      location.lat,
      location.lon,
      missionTarget.lat,
      missionTarget.lon,
    );

    // DEBUG: Log the phase decision point
    debugPrint('┌─────────────────────────────────────────────────────────────');
    debugPrint('│ [SimulationRepository] PHASE DECISION');
    debugPrint('│ distanceMeters: ${distanceMeters.toStringAsFixed(2)} m');
    debugPrint('│ proximityMeters: ${proximityThreshold.toStringAsFixed(2)} m');
    debugPrint('│ isNaN: ${distanceMeters.isNaN}, isInfinite: ${distanceMeters.isInfinite}');

    // Determine phase - ONLY set nearTarget if distance is valid and within threshold
    MissionPhase newPhase;
    if (distanceMeters.isNaN || distanceMeters.isInfinite) {
      // Invalid distance - stay enRoute
      debugPrint('│ RESULT: enRoute (invalid distance)');
      newPhase = MissionPhase.enRoute;
    } else if (distanceMeters <= proximityThreshold) {
      // Within proximity - nearTarget!
      debugPrint('│ RESULT: nearTarget ✓ (${distanceMeters.toStringAsFixed(2)} <= ${proximityThreshold.toStringAsFixed(2)})');
      newPhase = MissionPhase.nearTarget;
    } else {
      // Outside proximity - enRoute
      debugPrint('│ RESULT: enRoute (${distanceMeters.toStringAsFixed(2)} > ${proximityThreshold.toStringAsFixed(2)})');
      newPhase = MissionPhase.enRoute;
    }
    debugPrint('└─────────────────────────────────────────────────────────────');

    // Build result based on phase
    if (newPhase == MissionPhase.nearTarget) {
      final successEvent = SimulationEvent(
        id: 'near_target',
        type: SimulationEventType.success,
        description:
            'Öğrenci hedefe yeterince yakın: ${current.mission.title}.',
        relatedIds: [current.mission.targetBuildingId],
      );

      final updatedState = MissionState(
        mission: current.mission,
        phase: MissionPhase.nearTarget,
        score: ScoreSnapshot(points: successPoints),
        recentEvents: [successEvent],
      );

      return SimulationResult(
        missionState: updatedState,
        events: [successEvent],
        distanceMeters: distanceMeters,
      );
    }

    // enRoute state
    final enRouteState = MissionState(
      mission: current.mission,
      phase: MissionPhase.enRoute,
      score: current.score,
      recentEvents: const [],
    );

    return SimulationResult(
      missionState: enRouteState,
      events: const [],
      distanceMeters: distanceMeters,
    );
  }

  /// Haversine formula to calculate distance between two GPS coordinates.
  /// Returns distance in METERS.
  /// 
  /// IMPORTANT: Always call as (lat1, lon1, lat2, lon2) - latitude first!
  double _haversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // meters (NOT km!)
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


