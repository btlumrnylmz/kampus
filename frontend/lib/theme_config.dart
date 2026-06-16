import 'package:flutter/material.dart';

/// YYÜ Kampüs Danışmanı tema tanımları
class AppThemes {
  // YYÜ Renkleri
  static const Color yyuNavy = Color(0xFF003366);
  static const Color yyuTurquoise = Color(0xFF00CCCC);
  static const Color yyuGold = Color(0xFFD4A843);

  /// Açık Tema
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: yyuNavy,
      primary: yyuNavy,
      secondary: yyuTurquoise,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF0F172A),
    ),
  );

  /// Karanlık Tema
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: yyuNavy,
      primary: const Color(0xFF5B9BD5),
      secondary: yyuTurquoise,
      brightness: Brightness.dark,
      surface: const Color(0xFF1E1E2E),
    ),
    scaffoldBackgroundColor: const Color(0xFF121220),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Color(0xFF1E1E2E),
      foregroundColor: Colors.white,
    ),
  );
}
