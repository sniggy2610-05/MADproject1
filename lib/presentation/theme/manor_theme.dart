import 'package:flutter/material.dart';

class ManorColors {
  static const background = Color(0xFF171315);
  static const card = Color(0xFF292024);
  static const burgundy = Color(0xFF762B3A);
  static const darkBurgundy = Color(0xFF421C28);
  static const ivory = Color(0xFFFBF3E5);
  static const parchment = Color(0xFFEADFC8);
  static const gold = Color(0xFFD6AD69);
  static const muted = Color(0xFFB9A9A0);
}

class ManorTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ManorColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ManorColors.burgundy,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ManorColors.background,
        foregroundColor: ManorColors.ivory,
      ),
      cardTheme: CardThemeData(
        color: ManorColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ManorColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
