import 'package:flutter/material.dart';

/// 앱 전체에서 쓰는 따뜻한 종이·잉크 팔레트.
abstract final class Palette {
  /// 크림색 종이 배경.
  static const cream = Color(0xFFFAF3E7);

  /// 살짝 어두운 종이 (카드, 시트 배경).
  static const creamDark = Color(0xFFF2E8D8);

  /// 만년필 잉크색 — 기본 텍스트와 손글씨 획.
  static const ink = Color(0xFF3B362E);

  /// 흐린 잉크 — 보조 텍스트.
  static const inkFaded = Color(0xFF8A8172);

  /// 테라코타 — 포인트/액션 색.
  static const terracotta = Color(0xFFC4795B);

  /// 세이지 그린 — AI 답장의 잉크색.
  static const sage = Color(0xFF6E7F5E);

  /// 황혼 보라 — 무드 포인트.
  static const dusk = Color(0xFF6B5B73);

  /// 종이 위 흐린 괘선 색.
  static const ruleLine = Color(0x143B362E);

  /// 종이 질감 반점 색.
  static const speckle = Color(0x0A3B362E);
}
