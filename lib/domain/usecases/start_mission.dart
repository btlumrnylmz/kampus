import 'package:kampus/domain/entities/mission.dart';
import 'package:kampus/domain/entities/mission_state.dart';
import 'package:kampus/domain/entities/simulation_event.dart';
import 'package:kampus/domain/repositories/mission_repository.dart';

class StartMission {
  final MissionRepository missionRepository;
  const StartMission(this.missionRepository);

  Future<MissionState> call(Mission mission) async {
    final initialState = MissionState(
      mission: mission,
      phase: MissionPhase.enRoute,
      score: const ScoreSnapshot(points: 0),
      recentEvents: const <SimulationEvent>[],
    );
    await missionRepository.setActiveMission(mission);
    await missionRepository.updateMissionState(initialState);
    return initialState;
  }
}


