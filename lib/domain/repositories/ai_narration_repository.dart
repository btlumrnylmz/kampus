import 'package:kampus/domain/entities/ai_narration_result.dart';
import 'package:kampus/domain/entities/mission_state.dart';
import 'package:kampus/domain/entities/rag_context.dart';
import 'package:kampus/domain/entities/simulation_event.dart';

abstract class AiNarrationRepository {
  Future<AiNarrationResult> narrate({
    required MissionState missionState,
    required List<SimulationEvent> events,
    required RagContext ragContext,
  });
}


