import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'palette.dart';

/// 따뜻한 종이 위 잉크 느낌의 Material 3 테마.
abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Palette.terracotta,
      surface: Palette.cream,
      onSurface: Palette.ink,
    );

    TextStyle serif(TextStyle? base) => GoogleFonts.gowunBatang(
          textStyle: base ?? const TextStyle(),
          color: Palette.ink,
        );

    final baseText = ThemeData.light().textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Palette.cream,
      textTheme: TextTheme(
        displaySmall: serif(baseText.displaySmall),
        headlineMedium: serif(baseText.headlineMedium),
        headlineSmall: serif(baseText.headlineSmall),
        titleLarge: serif(baseText.titleLarge),
        titleMedium: serif(baseText.titleMedium),
        titleSmall: serif(baseText.titleSmall),
        bodyLarge: serif(baseText.bodyLarge),
        bodyMedium: serif(baseText.bodyMedium),
        bodySmall: serif(baseText.bodySmall).copyWith(color: Palette.inkFaded),
        labelLarge: serif(baseText.labelLarge),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Palette.ink,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Palette.terracotta,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Palette.creamDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(color: Palette.ruleLine),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Palette.ink,
        contentTextStyle: GoogleFonts.gowunBatang(color: Palette.cream),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Palette.cream,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Palette.creamDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: Palette.inkFaded),
      ),
    );
  }
}
