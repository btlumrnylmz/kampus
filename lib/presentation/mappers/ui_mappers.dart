import 'package:kampus/domain/entities/ai_narration_result.dart';
import 'package:kampus/domain/entities/mission_state.dart';

class MissionUiModel {
  final String title;
  final String statusText;
  final int points;
  final String? aiExplanation;
  final List<String> sources;

  const MissionUiModel({
    required this.title,
    required this.statusText,
    required this.points,
    required this.aiExplanation,
    required this.sources,
  });
}

MissionUiModel mapToUi(
  MissionState state,
  AiNarrationResult? aiNarration,
) {
  String statusText;
  switch (state.phase) {
    case MissionPhase.enRoute:
      statusText = 'Hedefe ilerleniyor';
      break;
    case MissionPhase.nearTarget:
      statusText = 'Hedefe ulaşıldı';
      break;
    case MissionPhase.success:
      statusText = 'Görev tamamlandı';
      break;
    case MissionPhase.failed:
      statusText = 'Görev başarısız';
      break;
  }

  final aiExplanation = aiNarration?.missionExplanation;
  final sources = aiNarration?.sources ?? const <String>[];

  return MissionUiModel(
    title: state.mission.title,
    statusText: statusText,
    points: state.score.points,
    aiExplanation: aiExplanation,
    sources: sources,
  );
}


