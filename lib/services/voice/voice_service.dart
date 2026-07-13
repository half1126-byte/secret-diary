import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 기기 내장 TTS — 무료·오프라인. 폰이 아닌 플랫폼에서는 조용히 무시된다.
abstract class TtsService {
  Future<void> speak(String text, {String languageTag = 'ko-KR'});
  Future<void> stop();
  void dispose() {}
}

/// 기기 내장 음성 인식(STT) — 무료. [onResult]로 부분/최종 텍스트를 준다.
abstract class SttService {
  bool get isListening;

  /// 듣기 시작. 성공하면 true. 최종 결과가 나오면 스스로 멈춘다.
  Future<bool> start({
    required void Function(String text, bool isFinal) onResult,
    String localeId = 'ko_KR',
  });

  Future<void> stop();
  void dispose() {}
}

/// 'ko' 같은 짧은 언어 태그를 TTS가 아는 로케일로 넓힌다.
String ttsLocaleFor(String tag) {
  if (tag.contains('-')) return tag;
  const map = {
    'ko': 'ko-KR',
    'en': 'en-US',
    'ja': 'ja-JP',
    'zh': 'zh-CN',
    'es': 'es-ES',
    'fr': 'fr-FR',
    'de': 'de-DE',
  };
  return map[tag] ?? tag;
}

bool get _isMobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// flutter_tts 래퍼. 플러그인이 없는 환경(데스크톱/테스트)에서도 안전.
class RealTtsService implements TtsService {
  FlutterTts? _tts;
  bool _ready = false;

  Future<FlutterTts?> _ensure(String languageTag) async {
    if (!_isMobile) return null;
    try {
      final tts = _tts ??= FlutterTts();
      if (!_ready) {
        await tts.awaitSpeakCompletion(false);
        _ready = true;
      }
      await tts.setLanguage(languageTag);
      await tts.setSpeechRate(0.5);
      return tts;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> speak(String text, {String languageTag = 'ko-KR'}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final tts = await _ensure(languageTag);
    if (tts == null) return;
    try {
      await tts.stop();
      await tts.speak(trimmed);
    } catch (_) {
      // 보이스 미설치 등 — 낭독만 조용히 생략.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    stop();
  }
}

/// speech_to_text 래퍼. 권한 거부/미지원 환경에서는 start가 false를 돌려준다.
class RealSttService implements SttService {
  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;

  @override
  bool get isListening => _stt.isListening;

  @override
  Future<bool> start({
    required void Function(String text, bool isFinal) onResult,
    String localeId = 'ko_KR',
  }) async {
    if (!_isMobile) return false;
    try {
      if (!_initialized) {
        _initialized = await _stt.initialize();
      }
      if (!_initialized) return false;
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          partialResults: true,
          listenMode: ListenMode.dictation,
        ),
        onResult: (result) =>
            onResult(result.recognizedWords, result.finalResult),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    stop();
  }
}
