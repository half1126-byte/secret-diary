import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 언어(BCP-47 태그)별 무료 손글씨 폰트 매핑.
///
/// AI 답장과 인식된 텍스트를 작성 언어의 손글씨 느낌으로 보여준다.
/// 모든 폰트는 Google Fonts의 무료(OFL) 폰트.
abstract final class ScriptFonts {
  /// 지원 언어 목록: ML Kit digital ink 태그 → 한국어 표시 이름.
  static const supportedLanguages = <String, String>{
    'ko': '한국어',
    'en': 'English',
    'ja': '日本語',
    'zh-Hani': '中文',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'it': 'Italiano',
    'pt': 'Português',
    'ru': 'Русский',
    'ar': 'العربية',
    'hi': 'हिन्दी',
    'th': 'ไทย',
    'vi': 'Tiếng Việt',
    'id': 'Bahasa Indonesia',
    'tr': 'Türkçe',
    'nl': 'Nederlands',
    'pl': 'Polski',
    'sv': 'Svenska',
    'uk': 'Українська',
  };

  /// 언어 태그에 맞는 손글씨 스타일을 돌려준다.
  ///
  /// google_fonts는 첫 사용 시 네트워크에서 폰트를 받아 캐시한다.
  /// 실패하면 시스템 폰트로 자연스럽게 대체된다.
  static TextStyle styleFor(String languageTag, {TextStyle? base}) {
    final b = base ?? const TextStyle();
    final primary = languageTag.split('-').first.toLowerCase();
    try {
      switch (primary) {
        case 'ko':
          return GoogleFonts.nanumPenScript(textStyle: b);
        case 'ja':
          return GoogleFonts.yomogi(textStyle: b);
        case 'zh':
          return GoogleFonts.longCang(textStyle: b);
        case 'ar':
          return GoogleFonts.arefRuqaa(textStyle: b);
        case 'th':
          return GoogleFonts.itim(textStyle: b);
        case 'hi':
          return GoogleFonts.kalam(textStyle: b);
        case 'ru':
        case 'uk':
          return GoogleFonts.neucha(textStyle: b);
        default:
          // 라틴 계열 전반.
          return GoogleFonts.caveat(textStyle: b);
      }
    } catch (_) {
      // 폰트 로딩 실패 시 (오프라인 첫 실행 등) 시스템 폰트 사용.
      return b;
    }
  }

  /// 답장 폰트로 고를 수 있는 무료 손글씨 폰트들 (키 → 표시 이름).
  static const replyFontChoices = <String, String>{
    'auto': '언어에 맞게 자동',
    'nanumPenScript': '나눔 펜',
    'gaegu': '개구체',
    'hiMelody': '하이멜로디',
    'eastSeaDokdo': '동해독도',
    'yeonSung': '연성체',
    'caveat': 'Caveat',
    'shadowsIntoLight': 'Shadows Into Light',
  };

  /// [replyFontChoices]의 키로 폰트 스타일을 만든다. 모르는 키면 기본 폰트.
  static TextStyle byName(String name, {TextStyle? base}) {
    final b = base ?? const TextStyle();
    try {
      switch (name) {
        case 'nanumPenScript':
          return GoogleFonts.nanumPenScript(textStyle: b);
        case 'gaegu':
          return GoogleFonts.gaegu(textStyle: b);
        case 'hiMelody':
          return GoogleFonts.hiMelody(textStyle: b);
        case 'eastSeaDokdo':
          return GoogleFonts.eastSeaDokdo(textStyle: b);
        case 'yeonSung':
          return GoogleFonts.yeonSung(textStyle: b);
        case 'caveat':
          return GoogleFonts.caveat(textStyle: b);
        case 'shadowsIntoLight':
          return GoogleFonts.shadowsIntoLight(textStyle: b);
        default:
          return b;
      }
    } catch (_) {
      return b;
    }
  }

  /// 답장 스타일: 취향 폰트가 있으면 그걸, 아니면 언어에 맞는 폰트.
  static TextStyle replyStyle(
    String languageTag,
    String replyFont, {
    TextStyle? base,
  }) {
    if (replyFont == 'auto') return styleFor(languageTag, base: base);
    return byName(replyFont, base: base);
  }

  /// 손글씨 폰트가 대체로 작게 보이는 문제를 보정하는 배율.
  static double scaleFor(String languageTag) {
    final primary = languageTag.split('-').first.toLowerCase();
    switch (primary) {
      case 'ko':
      case 'zh':
        return 1.25;
      case 'ja':
        return 1.05;
      default:
        return 1.2;
    }
  }
}
