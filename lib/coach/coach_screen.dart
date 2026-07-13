import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_message.dart';
import '../providers.dart';
import '../services/ai/gemini_client.dart';
import 'coach_app.dart';
import 'coach_session.dart';

/// 팩폭상담소 — 단일 채팅 화면.
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  late final CoachSession _session;
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _session = CoachSession(
      repository: ref.read(diaryRepositoryProvider),
      settings: ref.read(settingsRepositoryProvider),
      gemini: ref.read(geminiClientProvider),
    )..init();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _session.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    await _session.send(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: CoachColors.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text('팩폭상담소', style: theme.textTheme.titleMedium),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('실행이 답이다',
                  style: theme.textTheme.bodySmall),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _session,
          builder: (context, _) {
            final stream = _session.messageStream;
            return Column(
              children: [
                Expanded(
                  child: stream == null
                      ? const SizedBox.shrink()
                      : StreamBuilder<List<ChatMessage>>(
                          stream: stream,
                          builder: (context, snapshot) {
                            final messages =
                                snapshot.data ?? const <ChatMessage>[];
                            if (messages.isEmpty &&
                                _session.status == CoachStatus.idle) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text('뭐부터 털어놓을 건데?',
                                        style: theme.textTheme.titleMedium),
                                    const SizedBox(height: 8),
                                    Text('상황. 핑계 말고.',
                                        style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              );
                            }
                            final items = <Widget>[
                              for (final m in messages)
                                _Bubble(
                                  text: m.text,
                                  isUser: m.role == MessageRole.user,
                                ),
                              if (_session.status == CoachStatus.thinking)
                                const _Bubble(text: '…', isUser: false),
                              if (_session.status == CoachStatus.failed)
                                _ErrorBubble(
                                  error: _session.lastError,
                                  onRetry: _session.retry,
                                ),
                            ];
                            return ListView.builder(
                              controller: _scroll,
                              reverse: true,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 12),
                              itemCount: items.length,
                              itemBuilder: (context, index) =>
                                  items[items.length - 1 - index],
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
                  color: CoachColors.bg,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: '핑계 말고 상황부터.',
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: _send,
                        icon: const Icon(Icons.arrow_upward_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: CoachColors.accent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? CoachColors.accent : CoachColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isUser ? 12 : 3),
            bottomRight: Radius.circular(isUser ? 3 : 12),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : CoachColors.text,
            fontSize: 15.5,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({required this.error, required this.onRetry});

  final GeminiErrorType? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = switch (error) {
      GeminiErrorType.noApiKey => '이 빌드엔 AI가 없다. 제작자한테 말해.',
      GeminiErrorType.rateLimited => '지금 몰렸다. 잠시 뒤에 다시.',
      GeminiErrorType.network => '네트워크부터 고쳐.',
      _ => '답 못 가져왔다.',
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CoachColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: CoachColors.accent,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
              ),
              child: const Text('다시'),
            ),
          ],
        ),
      ),
    );
  }
}
