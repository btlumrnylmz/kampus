import 'package:flutter/foundation.dart';

import '../../domain/entities/ai_narration_result.dart';
import '../../domain/entities/mission_state.dart';
import '../../domain/entities/rag_context.dart';
import '../../domain/entities/simulation_event.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/repositories/ai_narration_repository.dart';
import '../datasources/remote/rag_api_client.dart';

/// HTTP implementation of [AiNarrationRepository] that uses the RAG backend.
class AiNarrationRepositoryImpl implements AiNarrationRepository {
  final RagApiClient _client;

  AiNarrationRepositoryImpl({
    required RagApiClient client,
  }) : _client = client;

  @override
  Future<AiNarrationResult> narrate({
    required MissionState missionState,
    required List<SimulationEvent> events,
    required RagContext ragContext,
  }) async {
    // Build query from mission context
    final targetId = missionState.mission.targetBuildingId;
    final query = 'Bu bina hakkında kısa bilgi ver ve giriş/konum yönlendirmesi yap.';

    return askQuestion(
      query: query,
      location: null,
      missionState: missionState,
      nearbyAnchorId: targetId,
    );
  }

  /// Ask a custom question to the AI assistant.
  Future<AiNarrationResult> askQuestion({
    required String query,
    UserLocation? location,
    MissionState? missionState,
    String? nearbyAnchorId,
  }) async {
    try {
      debugPrint('[AiNarrationRepo] Asking: $query');

      // Build request
      final request = AnswerRequestDto(
        query: query,
        gps: location != null
            ? GpsDto(
                lat: location.lat,
                lon: location.lon,
                accuracyM: location.accuracyMeters,
              )
            : null,
        missionState: missionState != null
            ? MissionStateDto(
                missionId: missionState.mission.id,
                phase: missionState.phase.name,
                targetId: missionState.mission.targetBuildingId,
              )
            : null,
        nearbyAnchorId: nearbyAnchorId,
      );

      // Call backend
      final response = await _client.answer(request);

      // Map response to domain entity
      return _mapResponseToResult(response);
    } catch (e) {
      debugPrint('[AiNarrationRepo] Error: $e');
      return AiNarrationResult.error('Bağlantı hatası: $e');
    }
  }

  AiNarrationResult _mapResponseToResult(AnswerResponseDto response) {
    final status = _mapStatus(response.status);

    return AiNarrationResult(
      status: status,
      missionExplanation: response.answer,
      reasoning: response.contextUsed != null ? [response.contextUsed!] : [],
      nextActions: response.actions,
      sources: response.sources.map((s) => s.sourceId).toList(),
      message: response.message,
      suggestions: response.suggestions,
      confidence: response.confidence,
      modelUsed: response.modelUsed,
      latencyMs: response.meta.latencyMs,
      modelName: response.meta.model,
    );
  }

  AiNarrationStatus _mapStatus(String status) {
    switch (status) {
      case 'ok':
        return AiNarrationStatus.ok;
      case 'no_answer':
        return AiNarrationStatus.noAnswer;
      case 'out_of_scope':
        return AiNarrationStatus.outOfScope;
      case 'rejected':
        return AiNarrationStatus.rejected;
      default:
        return AiNarrationStatus.error;
    }
  }
}









