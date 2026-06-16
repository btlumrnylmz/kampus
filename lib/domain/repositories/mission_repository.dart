import 'package:kampus/domain/entities/mission.dart';
import 'package:kampus/domain/entities/mission_state.dart';

abstract class MissionRepository {
  Future<void> setActiveMission(Mission mission);
  Future<MissionState?> getActiveMissionState();
  Future<void> updateMissionState(MissionState state);
}


