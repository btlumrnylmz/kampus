import 'package:kampus/domain/entities/ai_narration_result.dart';
import 'package:kampus/domain/entities/mission_state.dart';
import 'package:kampus/domain/entities/rag_context.dart';
import 'package:kampus/domain/entities/simulation_event.dart';
import 'package:kampus/domain/repositories/ai_narration_repository.dart';

class MockAiNarrationRepository implements AiNarrationRepository {
  @override
  Future<AiNarrationResult> narrate({
    required MissionState missionState,
    required List<SimulationEvent> events,
    required RagContext ragContext,
  }) async {
    final highScoreChunks =
        ragContext.chunks.where((c) => c.score >= 0.8).toList();
    if (highScoreChunks.isEmpty) {
      return const AiNarrationResult(
        status: AiNarrationStatus.noAnswer,
        missionExplanation: null,
        reasoning: [],
        nextActions: [],
        sources: [],
      );
    }

    final sources = highScoreChunks.map((c) => c.sourceId).toList();
    final hoursChunk = highScoreChunks
        .firstWhere(
          (c) => c.sourceId.contains('hours'),
          orElse: () => highScoreChunks.first,
        )
        .text;

    final bool successEvent =
        events.any((e) => e.type == SimulationEventType.success);

    if (!successEvent) {
      return const AiNarrationResult(
        status: AiNarrationStatus.noAnswer,
        missionExplanation: null,
        reasoning: [],
        nextActions: [],
        sources: [],
      );
    }

    return AiNarrationResult(
      status: AiNarrationStatus.ok,
      missionExplanation:
          'Merkez Kütüphanesine ulaştınız. ${hoursChunk.split('.').first}.',
      reasoning: const [
        'Simülasyon, hedef binaya 50 metre içinde olunduğunu belirledi.'
      ],
      nextActions: const [
        'Kütüphane girişinden içeri geçebilir ve çalışma salonlarına yönelebilirsiniz.'
      ],
      sources: sources,
    );
  }
}


