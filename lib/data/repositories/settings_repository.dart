import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 설정 저장소.
///
/// Gemini API 키는 보안 저장소(Keychain/Keystore)에,
/// 나머지 가벼운 설정은 SharedPreferences에 둔다.
class SettingsRepository {
  SettingsRepository({
    FlutterSecureStorage? secureStorage,
    required SharedPreferencesAsync prefs,
  })  : _secure = secureStorage ?? const FlutterSecureStorage(),
        _prefs = prefs; // ignore: prefer_initializing_formals

  final FlutterSecureStorage _secure;
  final SharedPreferencesAsync _prefs;

  static const _keyApiKey = 'gemini_api_key';
  static const _keyLanguage = 'writing_language';
  static const _keyModel = 'gemini_model';

  static const defaultModel = 'gemini-2.5-flash';

  Future<String?> getGeminiApiKey() => _secure.read(key: _keyApiKey);

  Future<void> setGeminiApiKey(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _secure.delete(key: _keyApiKey);
    } else {
      await _secure.write(key: _keyApiKey, value: value.trim());
    }
  }

  Future<String> getLanguageTag({String fallback = 'ko'}) async =>
      await _prefs.getString(_keyLanguage) ?? fallback;

  Future<void> setLanguageTag(String tag) => _prefs.setString(_keyLanguage, tag);

  Future<String> getModel() async =>
      await _prefs.getString(_keyModel) ?? defaultModel;

  Future<void> setModel(String model) => _prefs.setString(_keyModel, model);
}
