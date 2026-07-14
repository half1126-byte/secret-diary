import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_diary/data/db/app_database.dart';
import 'package:secret_diary/data/repositories/settings_repository.dart';
import 'package:secret_diary/providers.dart';
import 'package:secret_diary/services/ai/gemini_client.dart';
import 'package:secret_diary/services/handwriting/fake_recognizer.dart';
import 'package:secret_diary/services/voice/voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// 플랫폼 채널 오류(플러그인 부재 등)를 흉내내는 인식기.
class ThrowingRecognizer extends FakeRecognizer {
  @override
  Future<bool> isModelDownloaded(String languageTag) async =>
      throw Exception('MissingPluginException');

  @override
  Future<void> downloadModel(String languageTag) async =>
      throw Exception('MissingPluginException');

  @override
  Future<List<String>> downloadedModels() async =>
      throw Exception('MissingPluginException');
}

/// 말한 텍스트를 기록만 하는 TTS.
class FakeTts implements TtsService {
  final spoken = <String>[];

  @override
  Future<void> speak(String text, {String languageTag = 'ko-KR'}) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

/// start 즉시 각본대로 최종 결과를 돌려주는 STT.
class FakeStt implements SttService {
  FakeStt({this.transcript = '가짜 음성 인식'});

  final String transcript;
  bool started = false;

  @override
  bool get isListening => false;

  @override
  Future<bool> start({
    required void Function(String text, bool isFinal) onResult,
    String localeId = 'ko_KR',
  }) async {
    started = true;
    onResult(transcript, true);
    return true;
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

/// 위젯 테스트용 공통 환경: 인메모리 DB/설정/가짜 인식기/모의 Gemini.
class TestEnv {
  TestEnv({
    String? apiKey,
    MockClient? geminiHttp,
    FakeRecognizer? recognizer,
  }) {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    db = AppDatabase.withExecutor(NativeDatabase.memory());

    settings = SettingsRepository(
      prefs: SharedPreferencesAsync(),
      // 빌드 내장 키를 테스트에서 흉내낸다 (빈 문자열 = 키 없는 빌드).
      apiKeyOverride: apiKey ?? '',
    );

    this.recognizer = recognizer ?? FakeRecognizer(result: '가짜 인식 결과');

    gemini = GeminiClient(
      httpClient: geminiHttp ??
          MockClient((_) async => http.Response('{}', 500)),
    );
  }

  late final AppDatabase db;
  late final SettingsRepository settings;
  late final FakeRecognizer recognizer;
  late final GeminiClient gemini;
  final tts = FakeTts();
  final stt = FakeStt();

  /// 테스트 끝에 호출: 트리를 내리고 drift 스트림 정리 타이머를 소진시킨다.
  static Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  List<Override> get overrides => [
        databaseProvider.overrideWithValue(db),
        settingsRepositoryProvider.overrideWithValue(settings),
        recognizerProvider.overrideWithValue(recognizer),
        geminiClientProvider.overrideWithValue(gemini),
        ttsServiceProvider.overrideWithValue(tts),
        sttServiceProvider.overrideWithValue(stt),
      ];

  Future<void> dispose() => db.close();
}
