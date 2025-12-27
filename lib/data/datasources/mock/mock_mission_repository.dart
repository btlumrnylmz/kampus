import 'package:kampus/domain/entities/mission.dart';
import 'package:kampus/domain/entities/mission_state.dart';
import 'package:kampus/domain/repositories/mission_repository.dart';

class MockMissionRepository implements MissionRepository {
  MissionState? _state;

  @override
  Future<MissionState?> getActiveMissionState() async => _state;

  @override
  Future<void> setActiveMission(Mission mission) async {
    // no-op for mock; state is created in StartMission
  }

  @override
  Future<void> updateMissionState(MissionState state) async {
    _state = state;
  }
}


