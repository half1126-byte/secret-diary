import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_message.dart';
import '../providers.dart';
import '../services/ai/gemini_client.dart';
import '../services/voice/voice_service.dart';
import 'coach_app.dart';
import 'coach_prompt.dart';
import 'coach_session.dart';
import 'coach_share_card.dart';

/// AI 답변 첫 줄의 [핑계지수 NN%] 태그를 분리한다.
({int? score, String body}) splitExcuseScore(String text) {
  final match = RegExp(r'^\[핑계지수\s*(\d{1,3})%?\]\s*').firstMatch(text);
  if (match == null) return (score: null, body: text);
  final score = int.parse(match.group(1)!).clamp(0, 100);
  return (score: score, body: text.substring(match.end).trimLeft());
}

/// ENTP — 단일 채팅 화면.
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  late final CoachSession _session;
  late final TtsService _tts;
  late final SttService _stt;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  String _heat = 'spicy';
  bool _voiceAlways = false; // 상시 음성 답변 토글.
  bool _listening = false;
  bool _speakNextReply = false; // 음성으로 물었으면 답도 음성으로.

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsServiceProvider);
    _stt = ref.read(sttServiceProvider);
    _session = CoachSession(
      repository: ref.read(diaryRepositoryProvider),
      settings: ref.read(settingsRepositoryProvider),
      gemini: ref.read(geminiClientProvider),
      onAiReply: _onAiReply,
    )..init();
    final settings = ref.read(settingsRepositoryProvider);
    settings.getCoachHeat().then((heat) {
      if (mounted) setState(() => _heat = heat);
    });
    settings.getCoachVoice().then((on) {
      if (mounted) setState(() => _voiceAlways = on);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _session.dispose();
    _stt.stop();
    _tts.stop();
    super.dispose();
  }

  void _onAiReply(String text) {
    if (!_voiceAlways && !_speakNextReply) return;
    _speakNextReply = false;
    _tts.speak(splitExcuseScore(text).body);
  }

  Future<void> _send({bool fromVoice = false}) async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    _speakNextReply = fromVoice;
    await _session.send(text);
  }

  /// 마이크 토글: 말하면 글자로 받아 적고, 문장이 끝나면 자동 전송.
  Future<void> _toggleMic() async {
    if (_listening) {
      await _stt.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    await _tts.stop();
    final ok = await _stt.start(
      localeId: 'ko_KR',
      onResult: (text, isFinal) {
        if (!mounted) return;
        _input.text = text;
        if (isFinal) {
          setState(() => _listening = false);
          _send(fromVoice: true);
        }
      },
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _listening = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('마이크를 못 쓴다. 권한 확인하고 다시. (이 기기가 음성 인식 미지원일 수도)'),
        ),
      );
    }
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
            Text('ENTP', style: theme.textTheme.titleMedium),
          ],
        ),
        actions: [
          // 상시 음성 답변 (꺼져 있어도 음성 질문에는 음성으로 답한다).
          IconButton(
            tooltip: _voiceAlways ? '음성 답변 끄기' : '음성 답변 켜기',
            icon: Icon(
              _voiceAlways ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              size: 21,
              color: _voiceAlways ? CoachColors.accent : CoachColors.textFaded,
            ),
            onPressed: () async {
              setState(() => _voiceAlways = !_voiceAlways);
              if (!_voiceAlways) await _tts.stop();
              await ref
                  .read(settingsRepositoryProvider)
                  .setCoachVoice(_voiceAlways);
            },
          ),
          // 팩폭 강도 조절 — 순한맛 / 매운맛 / 불닭맛.
          PopupMenuButton<String>(
            tooltip: '팩폭 강도',
            color: CoachColors.surface,
            onSelected: (heat) async {
              setState(() => _heat = heat);
              await ref.read(settingsRepositoryProvider).setCoachHeat(heat);
            },
            itemBuilder: (context) => [
              for (final entry in CoachPrompt.heats.entries)
                PopupMenuItem(
                  value: entry.key,
                  child: Text(
                    '${entry.key == _heat ? '✓ ' : ''}🌶 ${entry.value.label}',
                    style: const TextStyle(color: CoachColors.text),
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  '🌶 ${CoachPrompt.heats[_heat]?.label ?? '매운맛'}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
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
                                    Text('무슨 고민인데? 말해봐.',
                                        style: theme.textTheme.titleMedium),
                                    const SizedBox(height: 8),
                                    Text('들어주고, 핵심 찌르고, 해결책까지.',
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
                                const _Bubble(text: '핑계 스캔 중…', isUser: false),
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
                // 찔리는 퀵리플 — 탭 한 번으로 팩폭 유도.
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final chip in const [
                        '인증한다. 했다.',
                        '핑계 대자면...',
                        '내일부터 진짜 한다',
                        '3분만 쉬고',
                        '반박 가능?',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(chip,
                                style: const TextStyle(
                                    color: CoachColors.text, fontSize: 13)),
                            backgroundColor: CoachColors.surface,
                            side: const BorderSide(
                                color: CoachColors.surfaceLight),
                            onPressed: () => _session.send(chip),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
                  color: CoachColors.bg,
                  child: Row(
                    children: [
                      // 말로 질문 — 기기 내장 음성 인식(무료).
                      IconButton(
                        tooltip: _listening ? '듣는 중… (탭해서 중지)' : '말로 질문',
                        onPressed: _toggleMic,
                        icon: Icon(
                          _listening ? Icons.mic : Icons.mic_none_rounded,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: _listening
                              ? CoachColors.accent
                              : CoachColors.surface,
                          foregroundColor: _listening
                              ? Colors.white
                              : CoachColors.textFaded,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: _listening
                                ? '듣고 있다. 말해.'
                                : '고민을 풀어놔 봐. 해결까지 간다.',
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
    final parsed =
        isUser ? (score: null, body: text) : splitExcuseScore(text);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        // AI 답변 꾹 누르면 공유용 팩폭 카드.
        onLongPress: isUser
            ? null
            : () => showShareCard(
                  context,
                  quote: parsed.body,
                  excuseScore: parsed.score,
                ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (parsed.score != null) ...[
                _ExcuseMeter(score: parsed.score!),
                const SizedBox(height: 8),
              ],
              Text(
                parsed.body,
                style: TextStyle(
                  color: isUser ? Colors.white : CoachColors.text,
                  fontSize: 15.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 말풍선 안 핑계지수 도장.
class _ExcuseMeter extends StatelessWidget {
  const _ExcuseMeter({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.05,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: CoachColors.accent, width: 1.6),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          '핑계지수 $score%',
          style: const TextStyle(
            color: CoachColors.accent,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 0.5,
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
