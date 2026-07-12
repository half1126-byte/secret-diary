import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secret_diary/data/db/app_database.dart';
import 'package:secret_diary/data/repositories/settings_repository.dart';
import 'package:secret_diary/providers.dart';
import 'package:secret_diary/services/ai/gemini_client.dart';
import 'package:secret_diary/services/handwriting/fake_recognizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// 위젯 테스트용 공통 환경: 인메모리 DB/설정/가짜 인식기/모의 Gemini.
class TestEnv {
  TestEnv({String? apiKey, MockClient? geminiHttp}) {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    db = AppDatabase.withExecutor(NativeDatabase.memory());

    secureStorage = MockSecureStorage();
    when(() => secureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => apiKey);
    when(() => secureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'))).thenAnswer((_) async {});
    when(() => secureStorage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});

    settings = SettingsRepository(
      secureStorage: secureStorage,
      prefs: SharedPreferencesAsync(),
    );

    recognizer = FakeRecognizer(result: '가짜 인식 결과');

    gemini = GeminiClient(
      httpClient: geminiHttp ??
          MockClient((_) async => http.Response('{}', 500)),
    );
  }

  late final AppDatabase db;
  late final MockSecureStorage secureStorage;
  late final SettingsRepository settings;
  late final FakeRecognizer recognizer;
  late final GeminiClient gemini;

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
      ];

  Future<void> dispose() => db.close();
}
