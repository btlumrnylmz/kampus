import 'package:kampus/domain/entities/ai_narration_result.dart';
import 'package:kampus/domain/entities/mission_state.dart';
import 'package:kampus/domain/entities/rag_context.dart';
import 'package:kampus/domain/entities/simulation_event.dart';
import 'package:kampus/domain/entities/user_location.dart';
import 'package:kampus/domain/repositories/mission_repository.dart';
import 'package:kampus/domain/repositories/rag_repository.dart';
import 'package:kampus/domain/usecases/evaluate_mission_rules.dart';
import 'package:kampus/domain/usecases/request_ai_narration.dart';

class UpdateLocationResult {
  final MissionState missionState;
  final List<SimulationEvent> simulationEvents;
  final AiNarrationResult? aiNarration;
  
  /// Distance from user location to target in meters.
  /// Single source of truth - computed by SimulationRepository.
  final double distanceMeters;

  const UpdateLocationResult({
    required this.missionState,
    required this.simulationEvents,
    this.aiNarration,
    required this.distanceMeters,
  });
}

class UpdateLocation {
  final MissionRepository missionRepository;
  final EvaluateMissionRules evaluateMissionRules;
  final RequestAiNarration requestAiNarration;
  final RagRepository ragRepository;

  const UpdateLocation({
    required this.missionRepository,
    required this.evaluateMissionRules,
    required this.requestAiNarration,
    required this.ragRepository,
  });

  Future<UpdateLocationResult> call(UserLocation location) async {
    final current = await missionRepository.getActiveMissionState();
    if (current == null) {
      throw StateError('No active mission.');
    }

    final simulationResult = await evaluateMissionRules(
      location: location,
      current: current,
    );

    AiNarrationResult? narration;
    if (simulationResult.missionState.phase == MissionPhase.nearTarget ||
        simulationResult.missionState.phase == MissionPhase.success) {
      final RagContext ragContext =
          await ragRepository.getContextForMission(simulationResult.missionState.mission);
      narration = await requestAiNarration(
        missionState: simulationResult.missionState,
        simulationEvents: simulationResult.events,
        ragContext: ragContext,
      );
    }

    return UpdateLocationResult(
      missionState: simulationResult.missionState,
      simulationEvents: simulationResult.events,
      aiNarration: narration,
      distanceMeters: simulationResult.distanceMeters,
    );
  }
}


