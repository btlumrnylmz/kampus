import 'package:kampus/domain/entities/ai_narration_result.dart';
import 'package:kampus/domain/entities/mission_state.dart';
import 'package:kampus/domain/entities/rag_context.dart';
import 'package:kampus/domain/entities/simulation_event.dart';
import 'package:kampus/domain/repositories/ai_narration_repository.dart';

class RequestAiNarration {
  final AiNarrationRepository repository;
  const RequestAiNarration(this.repository);

  Future<AiNarrationResult> call({
    required MissionState missionState,
    required List<SimulationEvent> simulationEvents,
    required RagContext ragContext,
  }) {
    return repository.narrate(
      missionState: missionState,
      events: simulationEvents,
      ragContext: ragContext,
    );
  }
}


