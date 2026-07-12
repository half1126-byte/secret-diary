import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/db/app_database.dart';
import 'data/repositories/diary_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'services/ai/gemini_client.dart';
import 'services/handwriting/fake_recognizer.dart';
import 'services/handwriting/mlkit_recognizer.dart';
import 'services/handwriting/recognizer.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final diaryRepositoryProvider = Provider<DiaryRepository>(
  (ref) => DiaryRepository(ref.watch(databaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(prefs: SharedPreferencesAsync()),
);

final recognizerProvider = Provider<HandwritingRecognizer>((ref) {
  // ML Kit은 실기기에서만 동작. 그 외(테스트 등)에는 가짜 인식기.
  final isMobile = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  final recognizer = isMobile ? MlKitRecognizer() : FakeRecognizer();
  ref.onDispose(recognizer.dispose);
  return recognizer;
});

final geminiClientProvider = Provider<GeminiClient>((ref) {
  final client = GeminiClient();
  ref.onDispose(client.dispose);
  return client;
});

/// 현재 쓰기 언어 (BCP-47). 시작 시 설정에서 불러온다.
final languageTagProvider =
    StateProvider<String>((ref) => 'ko');
