import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/mission.dart';
import '../../domain/entities/rag_context.dart';
import '../../domain/repositories/rag_repository.dart';

/// HTTP implementation of [RagRepository] that connects to the Python RAG backend.
class RagRepositoryHttp implements RagRepository {
  /// Base URL of the RAG backend.
  final String baseUrl;

  /// HTTP client for making requests.
  final http.Client _client;

  /// Request timeout duration.
  static const Duration _timeout = Duration(seconds: 30);

  RagRepositoryHttp({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<RagContext> getContextForMission(Mission mission) async {
    // Use search with building-related query
    final query = 'Bilgi: ${mission.targetBuildingId} ${mission.title}';
    return search(query);
  }

  @override
  Future<RagContext> search(
    String query, {
    int topK = 5,
    double minScore = 0.3,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/rag/search');

      debugPrint('[RAG HTTP] POST $uri');

      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': query,
              'top_k': topK,
              'min_score': minScore,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('[RAG HTTP] Error: ${response.statusCode} ${response.body}');
        return const RagContext(chunks: []);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status'] as String;

      if (status != 'ok') {
        debugPrint('[RAG HTTP] Status: $status - ${json['message']}');
        return const RagContext(chunks: []);
      }

      final results = json['results'] as List<dynamic>;
      final now = DateTime.now();

      final chunks = results.map((r) {
        final result = r as Map<String, dynamic>;
        return RagChunk(
          sourceId: result['doc_id'] as String,
          text: result['content'] as String,
          score: (result['score'] as num).toDouble(),
          timestamp: now,
        );
      }).toList();

      debugPrint('[RAG HTTP] Found ${chunks.length} results');

      return RagContext(chunks: chunks);
    } catch (e) {
      debugPrint('[RAG HTTP] Search error: $e');
      return const RagContext(chunks: []);
    }
  }

  @override
  Future<RagAnswerResult> getAnswer(String query, {String? buildingId}) async {
    try {
      final uri = Uri.parse('$baseUrl/rag/answer');

      debugPrint('[RAG HTTP] POST $uri');

      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': query,
              if (buildingId != null) 'building_id': buildingId,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('[RAG HTTP] Error: ${response.statusCode} ${response.body}');
        return RagAnswerResult(
          status: 'error',
          message: 'HTTP error: ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      return RagAnswerResult(
        status: json['status'] as String,
        answer: json['answer'] as String?,
        contextUsed: json['context_used'] as String?,
        sources: (json['sources'] as List<dynamic>?)
                ?.map((s) => s as String)
                .toList() ??
            [],
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        modelUsed: json['model_used'] as bool? ?? false,
        message: json['message'] as String?,
      );
    } catch (e) {
      debugPrint('[RAG HTTP] Answer error: $e');
      return RagAnswerResult(
        status: 'error',
        message: 'Connection error: $e',
      );
    }
  }

  /// Check if the backend is healthy.
  Future<bool> isHealthy() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return false;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['status'] == 'ok' && json['retriever_ready'] == true;
    } catch (e) {
      debugPrint('[RAG HTTP] Health check failed: $e');
      return false;
    }
  }
}









