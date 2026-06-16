import 'package:kampus/domain/entities/mission_state.dart';
import 'package:kampus/domain/entities/user_location.dart';
import 'package:kampus/domain/repositories/mission_repository.dart';
import 'package:kampus/domain/repositories/simulation_repository.dart';

class EvaluateMissionRules {
  final MissionRepository missionRepository;
  final SimulationRepository simulationRepository;

  const EvaluateMissionRules(
    this.missionRepository,
    this.simulationRepository,
  );

  Future<SimulationResult> call({
    required UserLocation location,
    required MissionState current,
  }) async {
    final result = await simulationRepository.evaluate(
      location: location,
      current: current,
    );
    await missionRepository.updateMissionState(result.missionState);
    return result;
  }
}


