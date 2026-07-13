import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/db/app_database.dart';
import 'data/models/writing_prefs.dart';
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
  // 데스크톱 미리보기: 마침표로 끝나는 문장을 돌려줘 자동 전송 흐름도 체험 가능.
  final recognizer = isMobile
      ? MlKitRecognizer()
      : FakeRecognizer(result: '오늘도 조용히 하루가 지나갔다.');
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

/// 답장 연출·전송 취향. 시작 시 설정에서 불러오고, 설정 화면에서 갱신한다.
final writingPrefsProvider =
    StateProvider<WritingPrefs>((ref) => const WritingPrefs());
