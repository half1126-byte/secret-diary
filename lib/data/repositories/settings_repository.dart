import 'package:shared_preferences/shared_preferences.dart';

import '../models/writing_prefs.dart';

/// 앱 설정 저장소.
///
/// Gemini API 키는 앱을 빌드하는 사람(제작자)이 빌드 시점에 내장한다:
/// `flutter build apk --dart-define=GEMINI_API_KEY=발급받은키`
/// 사용자에게는 키가 보이지 않고, 입력할 필요도 없다.
class SettingsRepository {
  SettingsRepository({
    required SharedPreferencesAsync prefs,
    String? apiKeyOverride,
  })  : _prefs = prefs, // ignore: prefer_initializing_formals
        _apiKey = apiKeyOverride ?? _embeddedKey;

  final SharedPreferencesAsync _prefs;
  final String _apiKey;

  /// 빌드 시 --dart-define으로 주입되는 내장 키.
  static const _embeddedKey = String.fromEnvironment('GEMINI_API_KEY');

  static const _keyLanguage = 'writing_language';
  static const _keyModel = 'gemini_model';

  static const defaultModel = 'gemini-2.5-flash';

  /// 내장 키. 없으면 null (AI 답장 비활성 빌드).
  Future<String?> getGeminiApiKey() async =>
      _apiKey.trim().isEmpty ? null : _apiKey.trim();

  /// AI 답장이 가능한 빌드인지.
  Future<bool> hasGeminiApiKey() async =>
      (await getGeminiApiKey()) != null;

  Future<String> getLanguageTag({String fallback = 'ko'}) async =>
      await _prefs.getString(_keyLanguage) ?? fallback;

  Future<void> setLanguageTag(String tag) => _prefs.setString(_keyLanguage, tag);

  Future<String> getModel() async =>
      await _prefs.getString(_keyModel) ?? defaultModel;

  Future<void> setModel(String model) => _prefs.setString(_keyModel, model);

  static const _keyReplyFont = 'reply_font';
  static const _keyReplyScale = 'reply_scale';
  static const _keyRevealMs = 'reveal_ms_per_char';
  static const _keyAutoSendMs = 'auto_send_ms';

  Future<WritingPrefs> getWritingPrefs() async => WritingPrefs(
        replyFont: await _prefs.getString(_keyReplyFont) ?? 'auto',
        replyScale: await _prefs.getDouble(_keyReplyScale) ?? 1.0,
        revealMsPerChar: await _prefs.getInt(_keyRevealMs) ?? 60,
        autoSendMs: await _prefs.getInt(_keyAutoSendMs) ?? 2200,
      );

  Future<void> setWritingPrefs(WritingPrefs prefs) async {
    await _prefs.setString(_keyReplyFont, prefs.replyFont);
    await _prefs.setDouble(_keyReplyScale, prefs.replyScale);
    await _prefs.setInt(_keyRevealMs, prefs.revealMsPerChar);
    await _prefs.setInt(_keyAutoSendMs, prefs.autoSendMs);
  }
}
