import 'package:flutter/material.dart';

import 'coach_screen.dart';

/// 팩폭상담소 — 차갑고 사무적인 다크 테마.
abstract final class CoachColors {
  static const bg = Color(0xFF15171C);
  static const surface = Color(0xFF1F232B);
  static const surfaceLight = Color(0xFF2A2F3A);
  static const accent = Color(0xFFFF5A36);
  static const text = Color(0xFFE9EDF2);
  static const textFaded = Color(0xFF8B93A1);
}

class CoachApp extends StatelessWidget {
  const CoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '팩폭상담소',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: CoachColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: CoachColors.accent,
          brightness: Brightness.dark,
          surface: CoachColors.bg,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: CoachColors.bg,
          foregroundColor: CoachColors.text,
          elevation: 0,
          centerTitle: false,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: CoachColors.text, fontSize: 15.5),
          bodySmall: TextStyle(color: CoachColors.textFaded, fontSize: 12.5),
          titleMedium: TextStyle(
            color: CoachColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: CoachColors.surface,
          hintStyle: const TextStyle(color: CoachColors.textFaded),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: CoachColors.surfaceLight,
          contentTextStyle: TextStyle(color: CoachColors.text),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const CoachScreen(),
    );
  }
}
