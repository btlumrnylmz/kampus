import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting game state (score and collected items).
class GameStorageService {
  static const String _keyScore = 'game_score';
  static const String _keyCollectedIds = 'game_collected_ids';

  /// Load the saved score.
  Future<int> loadScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyScore) ?? 0;
  }

  /// Save the score.
  Future<void> saveScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyScore, score);
  }

  /// Load the set of collected item IDs.
  Future<Set<String>> loadCollectedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final idsList = prefs.getStringList(_keyCollectedIds) ?? [];
    return idsList.toSet();
  }

  /// Save the set of collected item IDs.
  Future<void> saveCollectedIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyCollectedIds, ids.toList());
  }

  /// Clear all game data (for reset/debug).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyScore);
    await prefs.remove(_keyCollectedIds);
  }
}


