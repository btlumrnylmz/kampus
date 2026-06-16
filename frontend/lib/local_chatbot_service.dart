import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

/// Yerel LLaMA-Only API servisi ile iletişim kurar.
class LocalChatbotService {
  final String baseUrl;
  final bool debug;
  final int timeoutSeconds;

  LocalChatbotService({
    // Edge (Web) üzerinde doğrudan çalışması için localhost olarak ayarlandı.
    this.baseUrl = 'http://localhost:5001',
    this.debug = false,
    this.timeoutSeconds = 300, // Yapay zekanın uzun cevapları için 5 dakikaya çıkarıldı
  });

  /// Sağlık kontrolü yapar
  Future<bool> isHealthy() async {
    try {
      if (debug) print('[LocalChatbot] Sağlık kontrolü: $baseUrl/health');

      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (debug) print('[LocalChatbot] Sağlık: $data');
        return data['status'] == 'ok';
      }
      return false;
    } catch (e) {
      if (debug) print('[LocalChatbot] Sağlık kontrolü hatası: $e');
      return false;
    }
  }

  /// Mesaj gönderir ve cevap alır
  Future<ChatResponse> sendMessage(String message, {List<Map<String, String>> history = const []}) async {
    final stopwatch = Stopwatch()..start();

    try {
      if (debug) print('[LocalChatbot] Mesaj gönderiliyor: $message');

      final response = await http
          .post(
            Uri.parse('$baseUrl/chat'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'message': message,
              'history': history,
            }),
          )
          .timeout(Duration(seconds: timeoutSeconds));

      if (debug) {
        print(
          '[LocalChatbot] Yanıt süresi: ${stopwatch.elapsedMilliseconds}ms',
        );
        print('[LocalChatbot] Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (debug) print('[LocalChatbot] Data: $data');

        if (data['success'] == true) {
          return ChatResponse(
            success: true,
            response: data['response'] ?? 'Cevap alınamadı',
            confidence: (data['confidence'] ?? 0.0).toDouble(),
            matchedQuestion: data['matched_question'],
            location: data['location'] != null
                ? Map<String, dynamic>.from(data['location'])
                : null,
            data: data['data'], // Added this missing field
          );
        } else {
          return ChatResponse(
            success: false,
            response: data['error'] ?? 'Bilinmeyen hata',
            confidence: 0.0,
          );
        }
      } else {
        return ChatResponse(
          success: false,
          response: 'API hatası: ${response.statusCode}',
          confidence: 0.0,
        );
      }
    } on TimeoutException {
      if (debug) print('[LocalChatbot] Timeout hatası');
      return ChatResponse(
        success: false,
        response: 'Bağlantı zaman aşımına uğradı.',
        confidence: 0.0,
      );
    } catch (e) {
      if (debug) print('[LocalChatbot] Genel hata: $e');
      return ChatResponse(
        success: false,
        response: 'Bağlantı hatası: $e',
        confidence: 0.0,
      );
    }
  }

  /// Model bilgilerini getirir
  Future<Map<String, dynamic>?> getModelInfo() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/info'))
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      if (debug) print('[LocalChatbot] Model bilgisi hatası: $e');
      return null;
    }
  }
}

/// Chat yanıt modeli
class ChatResponse {
  final bool success;
  final String response;
  final double confidence;
  final String? matchedQuestion;
  final Map<String, dynamic>? location;
  final dynamic data; // Structured data field

  ChatResponse({
    required this.success,
    required this.response,
    required this.confidence,
    this.matchedQuestion,
    this.location,
    this.data,
  });

  /// Konum verisi var mı?
  bool get hasLocation => location != null;

  /// Ekstra veri var mı?
  bool get hasData => data != null;

  @override
  String toString() {
    return 'ChatResponse(success: $success, response: $response, confidence: $confidence, hasLocation: $hasLocation, hasData: $hasData)';
  }
}
