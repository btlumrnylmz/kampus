import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Sohbet geçmişi ve kullanıcı tercihlerini yerel olarak saklayan servis.
class ChatStorageService {
  static const String _messagesKey = 'chat_messages';
  static const String _themeKey = 'is_dark_mode';

  /// Mesajları kaydet
  static Future<void> saveMessages(List<Map<String, dynamic>> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(messages);
    await prefs.setString(_messagesKey, jsonStr);
  }

  /// Kaydedilmiş mesajları yükle
  static Future<List<Map<String, dynamic>>> loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_messagesKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Sohbet geçmişini temizle
  static Future<void> clearMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_messagesKey);
  }

  /// Karanlık mod tercihini kaydet
  static Future<void> saveThemePreference(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  /// Karanlık mod tercihini yükle
  static Future<bool> loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? false;
  }
}
