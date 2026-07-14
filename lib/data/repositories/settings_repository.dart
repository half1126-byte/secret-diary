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

  /// 'latest' 별칭이라 구글이 모델을 세대교체해도 계속 동작한다.
  /// (고정 모델명은 신규 사용자에게 제공 종료되며 404가 났음)
  static const defaultModel = 'gemini-flash-lite-latest';

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

  static const _keyPersona = 'reply_persona';

  /// 일기 친구 성격 (PromptBuilder.personas의 키).
  Future<String> getPersona() async =>
      await _prefs.getString(_keyPersona) ?? 'warm';

  Future<void> setPersona(String id) => _prefs.setString(_keyPersona, id);

  static const _keyCoachHeat = 'coach_heat';

  /// ENTP 채팅 상담의 팩폭 강도 ('mild' | 'spicy' | 'nuclear').
  Future<String> getCoachHeat() async =>
      await _prefs.getString(_keyCoachHeat) ?? 'spicy';

  Future<void> setCoachHeat(String heat) =>
      _prefs.setString(_keyCoachHeat, heat);

  static const _keyCoachVoice = 'coach_voice';

  /// ENTP 상시 음성 답변. 꺼져 있어도 음성으로 질문하면 그 답은 음성으로 온다.
  Future<bool> getCoachVoice() async =>
      await _prefs.getBool(_keyCoachVoice) ?? false;

  Future<void> setCoachVoice(bool on) => _prefs.setBool(_keyCoachVoice, on);

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
