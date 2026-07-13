import 'package:flutter/foundation.dart';

import '../data/models/chat_message.dart';
import '../data/models/diary_entry.dart';
import '../data/repositories/diary_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../services/ai/gemini_client.dart';
import 'coach_prompt.dart';

enum CoachStatus { idle, thinking, failed }

/// 팩폭상담소의 대화 세션 — 하나의 연속된 상담 스레드.
class CoachSession extends ChangeNotifier {
  CoachSession({
    required DiaryRepository repository,
    required SettingsRepository settings,
    required GeminiClient gemini,
  })  : _repository = repository, // ignore: prefer_initializing_formals
        _settings = settings, // ignore: prefer_initializing_formals
        _gemini = gemini; // ignore: prefer_initializing_formals

  final DiaryRepository _repository;
  final SettingsRepository _settings;
  final GeminiClient _gemini;

  DiaryEntry? _entry;
  bool _disposed = false;

  CoachStatus _status = CoachStatus.idle;
  CoachStatus get status => _status;

  GeminiErrorType? _lastError;
  GeminiErrorType? get lastError => _lastError;

  Stream<List<ChatMessage>>? _stream;
  Stream<List<ChatMessage>>? get messageStream => _stream;

  /// 기존 상담 스레드를 찾거나 새로 만든다.
  Future<void> init() async {
    _entry = await _repository.latestEntry(kind: EntryKind.counsel) ??
        await _repository.createEntry(
          languageTag: 'ko',
          kind: EntryKind.counsel,
        );
    _stream = _repository.watchMessages(_entry!.id);
    _notify();
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _entry == null) return;

    _status = CoachStatus.thinking;
    _lastError = null;
    _notify();

    await _repository.appendMessage(
      entryId: _entry!.id,
      role: MessageRole.user,
      text: trimmed,
    );
    await _requestReply();
  }

  Future<void> retry() => _requestReply();

  Future<void> _requestReply() async {
    _status = CoachStatus.thinking;
    _lastError = null;
    _notify();
    try {
      final apiKey = await _settings.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw const GeminiException(GeminiErrorType.noApiKey);
      }
      final messages = await _repository.getMessages(_entry!.id);
      if (messages.isEmpty) {
        _status = CoachStatus.idle;
        _notify();
        return;
      }
      final reply = await _gemini.generateReply(
        apiKey: apiKey,
        model: await _settings.getModel(),
        prompt: CoachPrompt.build(
          messages,
          heat: await _settings.getCoachHeat(),
        ),
      );
      await _repository.appendMessage(
        entryId: _entry!.id,
        role: MessageRole.ai,
        text: reply,
      );
      _status = CoachStatus.idle;
    } on GeminiException catch (e) {
      _status = CoachStatus.failed;
      _lastError = e.type;
    } catch (_) {
      _status = CoachStatus.failed;
      _lastError = GeminiErrorType.other;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
