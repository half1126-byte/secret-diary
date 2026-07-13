import 'package:flutter_test/flutter_test.dart';
import 'package:secret_diary/data/models/writing_prefs.dart';
import 'package:secret_diary/data/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late SettingsRepository repo;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    repo = SettingsRepository(
      prefs: SharedPreferencesAsync(),
      apiKeyOverride: '',
    );
  });

  test('답장 취향 기본값', () async {
    final prefs = await repo.getWritingPrefs();
    expect(prefs.replyFont, 'auto');
    expect(prefs.replyScale, 1.0);
    expect(prefs.revealMsPerChar, 60);
    expect(prefs.autoSendMs, 2200);
  });

  test('답장 취향 저장·복원 라운드트립', () async {
    await repo.setWritingPrefs(const WritingPrefs(
      replyFont: 'gaegu',
      replyScale: 1.4,
      revealMsPerChar: 100,
      autoSendMs: 3000,
    ));

    final loaded = await repo.getWritingPrefs();
    expect(loaded.replyFont, 'gaegu');
    expect(loaded.replyScale, 1.4);
    expect(loaded.revealMsPerChar, 100);
    expect(loaded.autoSendMs, 3000);
  });

  test('페르소나 저장·복원', () async {
    expect(await repo.getPersona(), 'warm');
    await repo.setPersona('tsundere');
    expect(await repo.getPersona(), 'tsundere');
  });

  test('빈 키는 AI 미준비로 취급', () async {
    expect(await repo.getGeminiApiKey(), isNull);
    expect(await repo.hasGeminiApiKey(), isFalse);

    final withKey = SettingsRepository(
      prefs: SharedPreferencesAsync(),
      apiKeyOverride: ' my-key ',
    );
    expect(await withKey.getGeminiApiKey(), 'my-key');
  });
}
