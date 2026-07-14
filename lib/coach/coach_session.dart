import 'package:flutter/foundation.dart';

import '../data/models/chat_message.dart';
import '../data/models/diary_entry.dart';
import '../data/repositories/diary_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../services/ai/gemini_client.dart';
import 'coach_prompt.dart';

enum CoachStatus { idle, thinking, failed }

/// ENTP의 대화 세션 — 하나의 연속된 상담 스레드.
class CoachSession extends ChangeNotifier {
  CoachSession({
    required DiaryRepository repository,
    required SettingsRepository settings,
    required GeminiClient gemini,
    this.onAiReply,
  })  : _repository = repository, // ignore: prefer_initializing_formals
        _settings = settings, // ignore: prefer_initializing_formals
        _gemini = gemini; // ignore: prefer_initializing_formals

  /// AI 답장이 도착했을 때 (예: 음성 낭독용).
  final void Function(String text)? onAiReply;

  final DiaryRepository _repository;
  final SettingsRepository _settings;
  final GeminiClient _gemini;

  DiaryEntry? _entry;
  bool _disposed = false;

  CoachStatus _status = CoachStatus.idle;
  CoachStatus get status => _status;

  GeminiErrorType? _lastError;
  GeminiErrorType? get lastError => _lastError;

  /// 스트리밍으로 도착 중인 답장 (타이핑되듯 실시간 표시용).
  String? _streamingText;
  String? get streamingText => _streamingText;

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
      // 스트리밍: 글자가 도착하는 대로 화면에 흘려보낸다 (빠른 답변 체감).
      var reply = '';
      final stream = _gemini.generateReplyStream(
        apiKey: apiKey,
        model: await _settings.getModel(),
        prompt: CoachPrompt.build(
          messages,
          heat: await _settings.getCoachHeat(),
        ),
      );
      await for (final text in stream) {
        reply = text;
        _streamingText = text;
        _notify();
      }
      await _repository.appendMessage(
        entryId: _entry!.id,
        role: MessageRole.ai,
        text: reply,
      );
      // 저장이 끝난 뒤에 지워야 말풍선이 깜빡이지 않는다.
      _streamingText = null;
      _status = CoachStatus.idle;
      if (!_disposed) onAiReply?.call(reply);
    } on GeminiException catch (e) {
      _streamingText = null;
      _status = CoachStatus.failed;
      _lastError = e.type;
    } catch (_) {
      _streamingText = null;
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
