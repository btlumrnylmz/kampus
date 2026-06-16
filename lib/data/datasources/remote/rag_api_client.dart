import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_config.dart';

// ============================================================
// DTOs
// ============================================================

/// GPS location DTO for API requests.
class GpsDto {
  final double lat;
  final double lon;
  final double? accuracyM;

  const GpsDto({
    required this.lat,
    required this.lon,
    this.accuracyM,
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
        if (accuracyM != null) 'accuracy_m': accuracyM,
      };
}

/// Mission state DTO for API requests.
class MissionStateDto {
  final String? missionId;
  final String? phase;
  final String? targetId;

  const MissionStateDto({
    this.missionId,
    this.phase,
    this.targetId,
  });

  Map<String, dynamic> toJson() => {
        if (missionId != null) 'mission_id': missionId,
        if (phase != null) 'phase': phase,
        if (targetId != null) 'target_id': targetId,
      };
}

/// Request DTO for /rag/answer endpoint.
class AnswerRequestDto {
  final String query;
  final GpsDto? gps;
  final MissionStateDto? missionState;
  final String? nearbyAnchorId;

  const AnswerRequestDto({
    required this.query,
    this.gps,
    this.missionState,
    this.nearbyAnchorId,
  });

  Map<String, dynamic> toJson() => {
        'query': query,
        if (gps != null) 'gps': gps!.toJson(),
        if (missionState != null) 'mission_state': missionState!.toJson(),
        if (nearbyAnchorId != null) 'nearby_anchor_id': nearbyAnchorId,
      };
}

/// Source reference in answer response.
class SourceDto {
  final String sourceId;
  final double score;

  const SourceDto({
    required this.sourceId,
    required this.score,
  });

  factory SourceDto.fromJson(Map<String, dynamic> json) {
    // Handle both object format and string format
    if (json.containsKey('source_id')) {
      return SourceDto(
        sourceId: json['source_id'] as String,
        score: (json['score'] as num?)?.toDouble() ?? 0.0,
      );
    }
    return const SourceDto(sourceId: 'unknown', score: 0.0);
  }

  factory SourceDto.fromString(String sourceId) {
    return SourceDto(sourceId: sourceId, score: 0.0);
  }
}

/// Metadata in answer response.
class MetaDto {
  final int? latencyMs;
  final String? model;

  const MetaDto({
    this.latencyMs,
    this.model,
  });

  factory MetaDto.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MetaDto();
    return MetaDto(
      latencyMs: json['latency_ms'] as int?,
      model: json['model'] as String?,
    );
  }
}

/// Response DTO for /rag/answer endpoint.
class AnswerResponseDto {
  /// Status: "ok", "no_answer", "out_of_scope", "rejected", "error"
  final String status;

  /// Generated answer (only for status="ok")
  final String? answer;

  /// Suggested actions (only for status="ok")
  final List<String> actions;

  /// Source references (only for status="ok")
  final List<SourceDto> sources;

  /// Error/info message (for non-ok statuses)
  final String? message;

  /// Suggestions for alternative queries (for no_answer/out_of_scope)
  final List<String> suggestions;

  /// Response metadata
  final MetaDto meta;

  /// Context used (if available)
  final String? contextUsed;

  /// Confidence score
  final double confidence;

  /// Whether model was used
  final bool modelUsed;

  const AnswerResponseDto({
    required this.status,
    this.answer,
    this.actions = const [],
    this.sources = const [],
    this.message,
    this.suggestions = const [],
    this.meta = const MetaDto(),
    this.contextUsed,
    this.confidence = 0.0,
    this.modelUsed = false,
  });

  factory AnswerResponseDto.fromJson(Map<String, dynamic> json) {
    // Parse sources - can be list of strings or list of objects
    final sourcesRaw = json['sources'] as List<dynamic>?;
    final sources = <SourceDto>[];
    if (sourcesRaw != null) {
      for (final s in sourcesRaw) {
        if (s is String) {
          sources.add(SourceDto.fromString(s));
        } else if (s is Map<String, dynamic>) {
          sources.add(SourceDto.fromJson(s));
        }
      }
    }

    return AnswerResponseDto(
      status: json['status'] as String? ?? 'error',
      answer: json['answer'] as String?,
      actions: (json['actions'] as List<dynamic>?)
              ?.map((a) => a as String)
              .toList() ??
          [],
      sources: sources,
      message: json['message'] as String?,
      suggestions: (json['suggestions'] as List<dynamic>?)
              ?.map((s) => s as String)
              .toList() ??
          [],
      meta: MetaDto.fromJson(json['meta'] as Map<String, dynamic>?),
      contextUsed: json['context_used'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      modelUsed: json['model_used'] as bool? ?? false,
    );
  }

  factory AnswerResponseDto.error(String message) {
    return AnswerResponseDto(
      status: 'error',
      message: message,
    );
  }

  bool get isOk => status == 'ok';
  bool get isNoAnswer => status == 'no_answer';
  bool get isOutOfScope => status == 'out_of_scope';
  bool get isRejected => status == 'rejected';
  bool get isError => status == 'error';
}

/// Health check response DTO.
class HealthDto {
  final String status;
  final bool retrieverReady;
  final String retrieverMode;
  final bool modelReady;
  final int documentsLoaded;

  const HealthDto({
    required this.status,
    required this.retrieverReady,
    required this.retrieverMode,
    required this.modelReady,
    required this.documentsLoaded,
  });

  factory HealthDto.fromJson(Map<String, dynamic> json) {
    return HealthDto(
      status: json['status'] as String? ?? 'error',
      retrieverReady: json['retriever_ready'] as bool? ?? false,
      retrieverMode: json['retriever_mode'] as String? ?? 'none',
      modelReady: json['model_ready'] as bool? ?? false,
      documentsLoaded: json['documents_loaded'] as int? ?? 0,
    );
  }

  bool get isHealthy => status == 'ok' && retrieverReady;
}

/// Search response DTO.
class SearchResponseDto {
  final String status;
  final String query;
  final List<SearchResultDto> results;
  final int totalFound;
  final String? message;

  const SearchResponseDto({
    required this.status,
    required this.query,
    required this.results,
    required this.totalFound,
    this.message,
  });

  factory SearchResponseDto.fromJson(Map<String, dynamic> json) {
    final resultsRaw = json['results'] as List<dynamic>? ?? [];
    final results = resultsRaw
        .map((r) => SearchResultDto.fromJson(r as Map<String, dynamic>))
        .toList();

    return SearchResponseDto(
      status: json['status'] as String? ?? 'error',
      query: json['query'] as String? ?? '',
      results: results,
      totalFound: json['total_found'] as int? ?? 0,
      message: json['message'] as String?,
    );
  }
}

/// Individual search result DTO.
class SearchResultDto {
  final String docId;
  final String title;
  final String content;
  final String? buildingId;
  final double score;
  final List<String> tags;

  const SearchResultDto({
    required this.docId,
    required this.title,
    required this.content,
    this.buildingId,
    required this.score,
    this.tags = const [],
  });

  factory SearchResultDto.fromJson(Map<String, dynamic> json) {
    return SearchResultDto(
      docId: json['doc_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      buildingId: json['building_id'] as String?,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      tags:
          (json['tags'] as List<dynamic>?)?.map((t) => t as String).toList() ??
              [],
    );
  }
}

// ============================================================
// API CLIENT
// ============================================================

/// HTTP client for the RAG backend API.
class RagApiClient {
  final String baseUrl;
  final http.Client _client;
  final Duration _timeout;

  RagApiClient({
    String? baseUrl,
    http.Client? client,
    Duration? timeout,
  })  : baseUrl = baseUrl ?? AppConfig.ragBackendUrl,
        _client = client ?? http.Client(),
        _timeout = timeout ?? AppConfig.aiRequestTimeout;

  /// Check backend health.
  Future<HealthDto> health() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      debugPrint('[RagApiClient] GET $uri');

      final response = await _client.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        debugPrint('[RagApiClient] Health error: ${response.statusCode}');
        return const HealthDto(
          status: 'error',
          retrieverReady: false,
          retrieverMode: 'none',
          modelReady: false,
          documentsLoaded: 0,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return HealthDto.fromJson(json);
    } catch (e) {
      debugPrint('[RagApiClient] Health exception: $e');
      return const HealthDto(
        status: 'error',
        retrieverReady: false,
        retrieverMode: 'none',
        modelReady: false,
        documentsLoaded: 0,
      );
    }
  }

  /// Search the knowledge base.
  Future<SearchResponseDto> search(String query, {int topK = 5}) async {
    try {
      final uri = Uri.parse('$baseUrl/rag/search');
      debugPrint('[RagApiClient] POST $uri');

      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': query,
              'top_k': topK,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('[RagApiClient] Search error: ${response.statusCode} ${response.body}');
        return SearchResponseDto(
          status: 'error',
          query: query,
          results: const [],
          totalFound: 0,
          message: 'HTTP error: ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SearchResponseDto.fromJson(json);
    } catch (e) {
      debugPrint('[RagApiClient] Search exception: $e');
      return SearchResponseDto(
        status: 'error',
        query: query,
        results: const [],
        totalFound: 0,
        message: _formatError(e),
      );
    }
  }

  /// Get an AI-generated answer.
  Future<AnswerResponseDto> answer(AnswerRequestDto request) async {
    try {
      final uri = Uri.parse('$baseUrl/rag/answer');
      debugPrint('[RagApiClient] POST $uri');
      debugPrint('[RagApiClient] Request: ${jsonEncode(request.toJson())}');

      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout);

      debugPrint('[RagApiClient] Response: ${response.statusCode} ${response.body.substring(0, response.body.length.clamp(0, 500))}');

      if (response.statusCode != 200) {
        return AnswerResponseDto.error('HTTP error: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return AnswerResponseDto.fromJson(json);
    } catch (e) {
      debugPrint('[RagApiClient] Answer exception: $e');
      return AnswerResponseDto.error(_formatError(e));
    }
  }

  String _formatError(dynamic e) {
    final errorStr = e.toString();
    if (errorStr.contains('SocketException') ||
        errorStr.contains('Connection refused')) {
      return 'Backend bağlantısı kurulamadı. Backend çalışıyor mu? ($baseUrl)';
    }
    if (errorStr.contains('TimeoutException')) {
      return 'İstek zaman aşımına uğradı. Lütfen tekrar deneyin.';
    }
    if (errorStr.contains('ClientException') && errorStr.contains('XMLHttpRequest')) {
      return 'CORS hatası: Backend\'de CORS ayarları yapılmalı.';
    }
    return 'Bağlantı hatası: $errorStr';
  }

  void dispose() {
    _client.close();
  }
}









