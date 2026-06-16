import 'package:flutter/material.dart';

/// Shared theme constants for the game mode UI.
/// Matches the existing dark campus navigation theme.
class GameTheme {
  // Background gradients (matching home page)
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1a1a2e), // Deep navy
      Color(0xFF16213e), // Medium navy
      Color(0xFF0f3460), // Dark blue
    ],
  );

  // Glassmorphism card style
  static BoxDecoration glassCard({
    double borderRadius = 20.0,
    Color? borderColor,
    double borderOpacity = 0.2,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.05),
        ],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: (borderColor ?? Colors.white).withValues(alpha: borderOpacity),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 20,
          spreadRadius: -5,
        ),
      ],
    );
  }

  // Colors
  static const Color primaryAccent = Color(0xFFe94560); // Red/pink
  static const Color secondaryAccent = Color(0xFF7c3aed); // Purple
  static const Color amberAccent = Color(0xFFffa726); // Amber/orange
  static const Color successGreen = Color(0xFF66bb6a); // Green
  static const Color warningOrange = Color(0xFFffa726); // Orange
  static const Color errorRed = Color(0xFFef5350); // Red

  // Text styles
  static const TextStyle titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    fontFamily: 'Segoe UI',
  );

  static const TextStyle labelStyle = TextStyle(
    color: Colors.white70,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    fontFamily: 'Segoe UI',
  );

  static const TextStyle valueStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.bold,
    fontFamily: 'Segoe UI',
  );

  // Spacing
  static const double cardPadding = 20.0;
  static const double cardBorderRadius = 20.0;
  static const double smallBorderRadius = 12.0;
}


