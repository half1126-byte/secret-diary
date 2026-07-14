import 'stroke.dart';

enum MessageRole { user, ai }

/// 일기 대화 스레드의 메시지 하나.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.entryId,
    required this.role,
    required this.text,
    required this.createdAt,
    this.strokes,
    this.pending = false,
  });

  final String id;
  final String entryId;
  final MessageRole role;

  /// 사용자 메시지: 인식(또는 수정)된 텍스트. AI 메시지: 답장 본문.
  final String text;

  final DateTime createdAt;

  /// 사용자 메시지의 실제 손글씨 원본. AI 메시지는 null.
  final List<DiaryStroke>? strokes;

  /// AI 답장 대기 중 여부 (전송 실패 후 재시도 대기 포함, DB에는 저장 안 함).
  final bool pending;

  ChatMessage copyWith({String? text, bool? pending}) => ChatMessage(
        id: id,
        entryId: entryId,
        role: role,
        text: text ?? this.text,
        createdAt: createdAt,
        strokes: strokes,
        pending: pending ?? this.pending,
      );
}
