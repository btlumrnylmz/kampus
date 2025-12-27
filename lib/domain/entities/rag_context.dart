class RagChunk {
  final String sourceId;
  final String text;
  final double score;
  final DateTime timestamp;

  const RagChunk({
    required this.sourceId,
    required this.text,
    required this.score,
    required this.timestamp,
  });
}

class RagContext {
  final List<RagChunk> chunks;
  const RagContext({required this.chunks});

  bool get hasSufficientEvidence =>
      chunks.isNotEmpty && chunks.any((c) => c.score >= 0.8);
}


