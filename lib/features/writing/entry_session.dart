import 'package:flutter/foundation.dart';

import '../../data/models/chat_message.dart';
import '../../data/models/stroke.dart';
import '../../data/repositories/diary_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/ai/gemini_client.dart';
import '../../services/ai/prompt_builder.dart';

/// AI 답장 진행 상태.
enum AiStatus { idle, thinking, failed }

/// 한 일기 항목의 대화 세션.
///
/// 사용자 메시지 저장 → Gemini 호출 → AI 답장 저장을 오케스트레이션한다.
/// 잉크와 텍스트는 API 호출 *전에* DB에 저장되므로 실패해도 유실되지 않는다.
class EntrySession extends ChangeNotifier {
  EntrySession({
    required DiaryRepository repository,
    required SettingsRepository settings,
    required GeminiClient gemini,
    required this.entryId,
  })  : _repository = repository, // ignore: prefer_initializing_formals
        _settings = settings, // ignore: prefer_initializing_formals
        _gemini = gemini; // ignore: prefer_initializing_formals

  final DiaryRepository _repository;
  final SettingsRepository _settings;
  final GeminiClient _gemini;
  final String entryId;

  AiStatus _status = AiStatus.idle;
  AiStatus get status => _status;

  GeminiErrorType? _lastError;
  GeminiErrorType? get lastError => _lastError;

  Stream<List<ChatMessage>> watchMessages() =>
      _repository.watchMessages(entryId);

  /// 손글씨 스냅샷을 사용자 메시지로 저장하고 AI 답장을 요청한다.
  Future<void> sendUserMessage({
    required String text,
    List<DiaryStroke>? strokes,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && (strokes == null || strokes.isEmpty)) return;

    await _repository.appendMessage(
      entryId: entryId,
      role: MessageRole.user,
      text: trimmed.isEmpty ? '(손글씨)' : trimmed,
      strokes: strokes,
    );
    await requestAiReply();
  }

  /// 마지막 사용자 메시지에 대한 AI 답장을 (재)요청한다.
  Future<void> requestAiReply() async {
    _status = AiStatus.thinking;
    _lastError = null;
    notifyListeners();

    try {
      final apiKey = await _settings.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw const GeminiException(GeminiErrorType.noApiKey);
      }
      final model = await _settings.getModel();

      // 현재 항목을 제외한 최근 일기들을 기억 블록으로.
      final snippets = await _repository.recentEntrySnippets(limit: 6);
      final messages = await _repository.getMessages(entryId);
      final currentFirst =
          messages.isEmpty ? null : messages.first.text;
      final memory = snippets
          .where((s) => currentFirst == null || !s.text.startsWith(_head(currentFirst)))
          .take(5)
          .toList();

      final prompt = PromptBuilder.build(snippets: memory, messages: messages);
      final reply = await _gemini.generateReply(
        apiKey: apiKey,
        model: model,
        prompt: prompt,
      );

      await _repository.appendMessage(
        entryId: entryId,
        role: MessageRole.ai,
        text: reply,
      );
      _status = AiStatus.idle;
    } on GeminiException catch (e) {
      _status = AiStatus.failed;
      _lastError = e.type;
    } catch (_) {
      _status = AiStatus.failed;
      _lastError = GeminiErrorType.other;
    }
    notifyListeners();
  }

  static String _head(String text) =>
      text.length > 50 ? text.substring(0, 50) : text;
}
