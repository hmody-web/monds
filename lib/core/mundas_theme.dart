import 'package:flutter/material.dart';
import 'mundas_colors.dart';

ThemeData buildMundasTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MundasColors.primary,
    brightness: Brightness.light,
    primary: MundasColors.primary,
    surface: MundasColors.paper,
    error: MundasColors.coral,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: MundasColors.background,
    fontFamily: 'ExpoArabic',
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.w700, color: MundasColors.ink),
      displayMedium: TextStyle(fontWeight: FontWeight.w700, color: MundasColors.ink),
      headlineLarge: TextStyle(fontWeight: FontWeight.w700, color: MundasColors.ink),
      headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: MundasColors.ink),
      titleLarge: TextStyle(fontWeight: FontWeight.w700, color: MundasColors.ink),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: MundasColors.ink),
      bodyLarge: TextStyle(fontWeight: FontWeight.w700, color: MundasColors.ink),
      bodyMedium: TextStyle(fontWeight: FontWeight.w700, color: MundasColors.ink),
      labelLarge: TextStyle(fontWeight: FontWeight.w700, color: MundasColors.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: MundasColors.line, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: MundasColors.line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: MundasColors.primary, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: MundasColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'ExpoArabic', fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
