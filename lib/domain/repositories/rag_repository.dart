import 'package:kampus/domain/entities/mission.dart';
import 'package:kampus/domain/entities/rag_context.dart';

/// Result of a RAG answer request.
class RagAnswerResult {
  /// Status: "ok", "no_answer", "rejected", "error"
  final String status;

  /// Generated answer (null if no_answer or model not ready)
  final String? answer;

  /// Retrieved context text
  final String? contextUsed;

  /// Source document IDs
  final List<String> sources;

  /// Confidence score (0.0 - 1.0)
  final double confidence;

  /// Whether the model generated the answer
  final bool modelUsed;

  /// Optional message
  final String? message;

  const RagAnswerResult({
    required this.status,
    this.answer,
    this.contextUsed,
    this.sources = const [],
    this.confidence = 0.0,
    this.modelUsed = false,
    this.message,
  });

  /// Whether the answer was successful (has context or generated answer).
  bool get isSuccess => status == 'ok';

  /// Whether the query was rejected by guardrails.
  bool get isRejected => status == 'rejected';

  /// Whether no relevant information was found.
  bool get isNoAnswer => status == 'no_answer';
}

abstract class RagRepository {
  /// Get context for a specific mission (legacy method).
  Future<RagContext> getContextForMission(Mission mission);

  /// Search the knowledge base for relevant documents.
  Future<RagContext> search(String query, {int topK = 5, double minScore = 0.3});

  /// Get an answer for a question using RAG.
  Future<RagAnswerResult> getAnswer(String query, {String? buildingId});
}


