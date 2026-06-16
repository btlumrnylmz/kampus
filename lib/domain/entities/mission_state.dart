import 'package:kampus/domain/entities/mission.dart';
import 'package:kampus/domain/entities/simulation_event.dart';

enum MissionPhase { enRoute, nearTarget, success, failed }

class ScoreSnapshot {
  final int points;
  const ScoreSnapshot({required this.points});
}

class MissionState {
  final Mission mission;
  final MissionPhase phase;
  final ScoreSnapshot score;
  final List<SimulationEvent> recentEvents;

  const MissionState({
    required this.mission,
    required this.phase,
    required this.score,
    required this.recentEvents,
  });

  MissionState copyWith({
    MissionPhase? phase,
    ScoreSnapshot? score,
    List<SimulationEvent>? recentEvents,
  }) {
    return MissionState(
      mission: mission,
      phase: phase ?? this.phase,
      score: score ?? this.score,
      recentEvents: recentEvents ?? this.recentEvents,
    );
  }
}


