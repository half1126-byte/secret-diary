import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/script_fonts.dart';
import '../../core/widgets/ink_fade_in.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/stroke.dart';
import '../../services/ai/gemini_client.dart';
import 'canvas/stroke_painter.dart';
import 'entry_session.dart';

/// 일기 대화 스레드.
///
/// 사용자 메시지는 실제 손글씨 잉크로, AI 답장은 언어별 손글씨 폰트로 보여준다.
class ChatThread extends StatelessWidget {
  const ChatThread({
    super.key,
    required this.messages,
    required this.languageTag,
    required this.status,
    required this.lastError,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final List<ChatMessage> messages;
  final String languageTag;
  final AiStatus status;
  final GeminiErrorType? lastError;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      for (final message in messages)
        message.role == MessageRole.user
            ? _UserBubble(message: message, languageTag: languageTag)
            : _AiBubble(message: message, languageTag: languageTag),
      if (status == AiStatus.thinking) const _ThinkingIndicator(),
      if (status == AiStatus.failed)
        lastError == GeminiErrorType.noApiKey
            ? _NoKeyCard(onOpenSettings: onOpenSettings)
            : _RetryCard(error: lastError, onRetry: onRetry),
    ];

    return ListView.separated(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) => items[items.length - 1 - index],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message, required this.languageTag});

  final ChatMessage message;
  final String languageTag;

  @override
  Widget build(BuildContext context) {
    final hasInk = message.strokes != null && message.strokes!.isNotEmpty;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Palette.creamDark,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: const Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasInk) ...[
              // 실제 손글씨 그대로 — 이 앱의 시그니처.
              SizedBox(
                width: 240,
                height: _inkHeight(message),
                child: CustomPaint(
                  painter: StrokesPainter(
                    strokes: message.strokes!,
                    color: Palette.ink,
                    fit: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message.text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 12),
              ),
            ] else
              Text(message.text, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  double _inkHeight(ChatMessage message) {
    final box = StrokeCodec.boundingBox(message.strokes!);
    if (box.width <= 0) return 60;
    return (240 * box.height / box.width).clamp(40.0, 220.0);
  }
}

class _AiBubble extends StatelessWidget {
  const _AiBubble({required this.message, required this.languageTag});

  final ChatMessage message;
  final String languageTag;

  @override
  Widget build(BuildContext context) {
    final style = ScriptFonts.styleFor(
      languageTag,
      base: TextStyle(
        fontSize: 19 * ScriptFonts.scaleFor(languageTag) / 1.2,
        color: Palette.sage,
        height: 1.5,
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: InkFadeIn(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.85,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(message.text, style: style),
        ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final dots = '·' * (1 + (_controller.value * 3).floor() % 3);
          return Text(
            '펜을 들고 있어요 $dots',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Palette.sage),
          );
        },
      ),
    );
  }
}

class _RetryCard extends StatelessWidget {
  const _RetryCard({required this.error, required this.onRetry});

  final GeminiErrorType? error;
  final VoidCallback onRetry;

  String get _message => switch (error) {
        GeminiErrorType.rateLimited =>
          'AI가 잠시 숨을 고르고 있어요.\n조금 뒤에 다시 시도해 주세요.',
        GeminiErrorType.invalidApiKey =>
          'API 키가 맞지 않는 것 같아요.\n설정에서 키를 다시 확인해 주세요.',
        GeminiErrorType.network => '인터넷 연결이 불안정해요.',
        _ => '답장을 가져오지 못했어요.',
      };

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      icon: Icons.auto_stories_outlined,
      message: _message,
      actionLabel: '다시 시도',
      onAction: onRetry,
    );
  }
}

class _NoKeyCard extends StatelessWidget {
  const _NoKeyCard({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      icon: Icons.auto_awesome_outlined,
      message: '이 빌드에는 AI 일기 친구가\n아직 준비되지 않았어요.',
      actionLabel: '설정 보기',
      onAction: onOpenSettings,
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Palette.creamDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.ruleLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: Palette.inkFaded),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(message,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: Palette.terracotta,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
