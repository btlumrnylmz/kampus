import 'package:kampus/domain/entities/mission.dart';
import 'package:kampus/domain/entities/rag_context.dart';
import 'package:kampus/domain/repositories/rag_repository.dart';

class MockRagDataSource implements RagRepository {
  final bool returnEmpty;
  MockRagDataSource({this.returnEmpty = false});

  @override
  Future<RagContext> getContextForMission(Mission mission) async {
    if (returnEmpty) {
      return const RagContext(chunks: []);
    }

    if (mission.targetBuildingId == 'central_library') {
      final now = DateTime.now();
      return RagContext(chunks: [
        RagChunk(
          sourceId: 'central_library_hours',
          text: 'Merkez Kütüphanesi çalışma saatleri 08:30-22:00.',
          score: 0.92,
          timestamp: now,
        ),
        RagChunk(
          sourceId: 'central_library_location',
          text: 'Merkez Kütüphanesi Kuzey Kampüsünde yer alır.',
          score: 0.9,
          timestamp: now,
        ),
        RagChunk(
          sourceId: 'central_library_feature',
          text: 'Kütüphanede geniş çalışma salonları (study halls) bulunur.',
          score: 0.88,
          timestamp: now,
        ),
      ]);
    }

    return const RagContext(chunks: []);
  }

  @override
  Future<RagContext> search(
    String query, {
    int topK = 5,
    double minScore = 0.3,
  }) async {
    // Mock search - return library info for any query containing "kütüphane"
    final queryLower = query.toLowerCase();
    final now = DateTime.now();

    if (queryLower.contains('kütüphane') || queryLower.contains('library')) {
      return RagContext(chunks: [
        RagChunk(
          sourceId: 'central_library_info',
          text: 'Van Yüzüncü Yıl Üniversitesi Merkez Kütüphanesi, kampüsün en büyük kütüphanesidir.',
          score: 0.92,
          timestamp: now,
        ),
      ]);
    }

    if (queryLower.contains('yemekhane') || queryLower.contains('yemek')) {
      return RagContext(chunks: [
        RagChunk(
          sourceId: 'cafeteria_info',
          text: 'Merkez Yemekhane, günlük 5000 öğrenci kapasitesine sahiptir.',
          score: 0.88,
          timestamp: now,
        ),
      ]);
    }

    return const RagContext(chunks: []);
  }

  @override
  Future<RagAnswerResult> getAnswer(String query, {String? buildingId}) async {
    // Mock answer - just return context for now (Phase 1 behavior)
    final context = await search(query);

    if (context.chunks.isEmpty) {
      return const RagAnswerResult(
        status: 'no_answer',
        message: 'Bu soru için bilgi tabanında yeterli bilgi bulunamadı.',
      );
    }

    return RagAnswerResult(
      status: 'ok',
      contextUsed: context.chunks.map((c) => c.text).join('\n'),
      sources: context.chunks.map((c) => c.sourceId).toList(),
      confidence: context.chunks.first.score,
      modelUsed: false,
      message: 'Mock response - backend not connected',
    );
  }
}


