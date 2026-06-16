import 'package:kampus/domain/entities/mission_state.dart';
import 'package:kampus/domain/entities/simulation_event.dart';
import 'package:kampus/domain/entities/user_location.dart';

class SimulationResult {
  final MissionState missionState;
  final List<SimulationEvent> events;
  
  /// Distance from user location to target in meters.
  /// Single source of truth for distance calculation.
  final double distanceMeters;

  SimulationResult({
    required this.missionState,
    required this.events,
    required this.distanceMeters,
  });
}

abstract class SimulationRepository {
  Future<SimulationResult> evaluate({
    required UserLocation location,
    required MissionState current,
  });
}


