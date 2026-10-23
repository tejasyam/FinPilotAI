import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF080F1B);
  static const surface = Color(0xFF151F2D);
  static const elevated = Color(0xFF1B2939);
  static const border = Color(0xFF293849);
  static const mint = Color(0xFF5FE0BE);
  static const purple = Color(0xFFA99AFB);
  static const muted = Color(0xFF91A0B2);
  static const coral = Color(0xFFFF8C82);
}

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.mint,
      secondary: AppColors.purple,
      surface: AppColors.surface,
      error: AppColors.coral,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.elevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.mint, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.muted),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(fontSize: 14, color: Colors.white),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.muted),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: Color(0xFF24453F),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 72,
    ),
  );
}
