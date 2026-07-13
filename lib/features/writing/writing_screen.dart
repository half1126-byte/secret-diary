import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/navigation/page_turn_route.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/script_fonts.dart';
import '../../core/widgets/notebook_page.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/diary_entry.dart';
import '../../data/models/stroke.dart';
import '../../providers.dart';
import '../settings/language_model_sheet.dart';
import '../settings/settings_screen.dart';
import 'canvas/handwriting_canvas.dart';
import 'canvas/stroke_painter.dart';
import 'chat_thread.dart';
import 'entry_session.dart';
import 'writing_controller.dart';

/// 쓰기 화면: 손글씨 캔버스 ↔ 대화 스레드.
class WritingScreen extends ConsumerStatefulWidget {
  const WritingScreen({super.key, required this.entry});

  final DiaryEntry entry;

  @override
  ConsumerState<WritingScreen> createState() => _WritingScreenState();
}

/// AI 답장을 진짜 필기처럼 그리는 위젯.
///
/// 문장마다 줄을 바꾸고, 줄마다 살짝 다른 기울기·들여쓰기를 줘서
/// 활자 느낌 대신 여백에 끄적인 쪽지 느낌을 낸다.
class _HandwrittenReply extends StatelessWidget {
  const _HandwrittenReply({
    required this.text,
    required this.progress,
    required this.style,
  });

  final String text;
  final double progress;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final lines = _WritingScreenState.splitNoteLines(text);
    final totalChars =
        lines.fold<int>(0, (sum, l) => sum + l.characters.length);
    var remaining = (totalChars * progress).round();
    final random = Random(text.hashCode);

    final children = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final chars = lines[i].characters;
      final show = remaining.clamp(0, chars.length);
      remaining -= chars.length;
      final angle = (random.nextDouble() - 0.5) * 0.045; // ±1.3도
      final indent = random.nextDouble() * 26;
      if (show <= 0) break;
      children.add(Padding(
        padding: EdgeInsets.only(left: indent, bottom: 10),
        child: Transform.rotate(
          angle: angle,
          alignment: Alignment.centerLeft,
          child: Text(chars.take(show).toString(), style: style),
        ),
      ));
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _WritingScreenState extends ConsumerState<WritingScreen>
    with TickerProviderStateMixin {
  late WritingController _writing;
  late EntrySession _session;
  late String _languageTag;

  /// true = 캔버스 모드, false = 대화 모드.
  bool _writingMode = true;

  String _sentText = '';

  /// 전송 직후 종이에 스며들며 사라지는 잉크.
  List<DiaryStroke>? _fadingStrokes;

  /// 획별 디졸브 시작 지연 (랜덤 순서로 번지게).
  List<double> _fadeDelays = const [];
  late final AnimationController _fadeController;

  /// 캔버스 위에 손글씨로 써지는 AI 답장.
  String? _replyReveal;
  late final AnimationController _revealController;

  @override
  void initState() {
    super.initState();
    // dispose에서 late 초기화가 일어나지 않도록 여기서 즉시 만든다.
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _fadingStrokes = null);
        }
      });
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _languageTag = widget.entry.languageTag;
    _writing = WritingController(
      recognizer: ref.read(recognizerProvider),
      languageTag: _languageTag,
      preContextProvider: () => _sentText,
    );
    // 문장 끝 마침표 → 잠시 뒤 자동 전송 (영상 속 마법의 트리거).
    _writing.onAutoSend = _send;
    _session = EntrySession(
      repository: ref.read(diaryRepositoryProvider),
      settings: ref.read(settingsRepositoryProvider),
      gemini: ref.read(geminiClientProvider),
      entryId: widget.entry.id,
      kind: widget.entry.kind,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _revealController.dispose();
    _writing.dispose();
    _session.dispose();
    super.dispose();
  }

  /// 더블터치 = "내 이야기는 여기까지" — 대기 없이 바로 보낸다.
  void _sendNow() {
    if (!_writing.hasInk && _writing.recognizedText.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    _send();
  }

  Future<void> _send() async {
    final snapshot = _writing.takeSnapshot();
    if (snapshot == null) return;
    _sentText = '$_sentText ${snapshot.text}'.trim();

    // 1) 방금 쓴 잉크가 획 하나씩, 랜덤한 순서로 번지며 스며든다.
    final random = Random();
    setState(() {
      _replyReveal = null;
      _fadingStrokes = snapshot.strokes;
      _fadeDelays = [
        for (final _ in snapshot.strokes) random.nextDouble() * 0.55,
      ];
    });
    _fadeController.forward(from: 0);

    // 2) 저장 + AI 답장 요청.
    await _session.sendUserMessage(
      text: snapshot.text,
      strokes: snapshot.strokes,
    );
    if (!mounted) return;

    // 메모는 조용히 담아두기만 한다.
    if (widget.entry.kind == EntryKind.memo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('메모에 담아뒀어요.'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    if (_session.status == AiStatus.failed) {
      // 오류는 대화 화면의 카드(재시도/안내)로 보여준다.
      setState(() {
        _fadingStrokes = null;
        _writingMode = false;
      });
      return;
    }

    // 아이디어 모드의 구조화된 답(목록/표)은 대화 화면에서 보여준다.
    if (widget.entry.kind == EntryKind.idea) {
      setState(() {
        _fadingStrokes = null;
        _writingMode = false;
      });
      return;
    }

    // 3) 답장이 손글씨로 한 글자씩 써진다 (속도는 취향 설정).
    final reply = _session.lastAiReply;
    if (reply != null && _writingMode) {
      setState(() {
        _fadingStrokes = null;
        _replyReveal = reply;
      });
      final msPerChar = ref.read(writingPrefsProvider).revealMsPerChar;
      _revealController.duration = Duration(
        milliseconds:
            (reply.characters.length * msPerChar).clamp(900, 15000),
      );
      _revealController.forward(from: 0);
    }
  }

  Future<void> _pickLanguage() async {
    final tag = await showLanguagePicker(context, current: _languageTag);
    if (tag == null || tag == _languageTag) return;
    if (!mounted) return;
    final ok =
        await ensureLanguageModel(context, ref.read(recognizerProvider), tag);
    // 모델 다운로드 시트가 떠 있는 동안 화면을 벗어났을 수 있다.
    if (!ok || !mounted) return;
    setState(() => _languageTag = tag);
    _writing.languageTag = tag;
    await ref.read(settingsRepositoryProvider).setLanguageTag(tag);
    ref.read(languageTagProvider.notifier).state = tag;
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('M월 d일 EEEE', 'ko').format(widget.entry.createdAt);
    final kindSuffix = widget.entry.kind == EntryKind.diary
        ? ''
        : ' · ${widget.entry.kind.label}';
    final languageName =
        ScriptFonts.supportedLanguages[_languageTag] ?? _languageTag;

    return Scaffold(
      appBar: AppBar(
        title: Text('$dateLabel$kindSuffix',
            style: Theme.of(context).textTheme.titleMedium),
        actions: [
          TextButton.icon(
            onPressed: _pickLanguage,
            icon: const Icon(Icons.translate, size: 16),
            label: Text(languageName),
            style: TextButton.styleFrom(foregroundColor: Palette.inkFaded),
          ),
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.more_horiz),
            onPressed: () => Navigator.of(context).push(
              PageTurnRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: NotebookPage(
        showRuleLines: _writingMode,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _writingMode ? _buildCanvas() : _buildThread(),
                ),
              ),
              if (_writingMode) _buildRecognitionBar(),
            ],
          ),
        ),
      ),
      floatingActionButton: _writingMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => setState(() => _writingMode = true),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('이어 쓰기'),
            ),
    );
  }

  Widget _buildCanvas() {
    final prefs = ref.watch(writingPrefsProvider);
    _writing.autoSendDelay = Duration(milliseconds: prefs.autoSendMs);

    return ListenableBuilder(
      key: const ValueKey('canvas'),
      listenable: Listenable.merge([_writing, _session]),
      builder: (context, _) {
        final idleEmpty = !_writing.hasInk &&
            _fadingStrokes == null &&
            _replyReveal == null &&
            _session.status != AiStatus.thinking;
        return Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                _writing.writingArea = constraints.biggest;
                return HandwritingCanvas(
                  strokes: _writing.strokes,
                  onDoubleTap: _sendNow,
                  onStrokeEnd: (stroke) {
                    // 새로 쓰기 시작하면 답장은 조용히 물러난다.
                    if (_replyReveal != null) {
                      setState(() => _replyReveal = null);
                    }
                    _writing.addStroke(stroke);
                  },
                );
              },
            ),
            // 전송된 잉크가 획 단위로 번지며 스며드는 레이어.
            if (_fadingStrokes != null)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _fadeController,
                  builder: (context, _) => CustomPaint(
                    size: Size.infinite,
                    painter: DissolvingStrokesPainter(
                      strokes: _fadingStrokes!,
                      delays: _fadeDelays,
                      progress: _fadeController.value,
                      color: Palette.ink,
                    ),
                  ),
                ),
              ),
            // AI 답장이 화면 가운데에서 손글씨로 한 글자씩 피어나는 레이어.
            if (_replyReveal != null)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _revealController,
                  builder: (context, _) => _HandwrittenReply(
                    text: _replyReveal!,
                    progress: _revealController.value,
                    style: ScriptFonts.replyStyle(
                      _languageTag,
                      prefs.replyFont,
                      base: TextStyle(
                        fontSize: 23 *
                            prefs.replyScale *
                            ScriptFonts.scaleFor(_languageTag) /
                            1.2,
                        color: Palette.sage,
                        height: 1.55,
                      ),
                    ),
                  ),
                ),
              ),
            // 답장을 기다리는 동안 — 일기장이 조용히 생각하는 느낌.
            if (_session.status == AiStatus.thinking &&
                !_writing.hasInk &&
                _fadingStrokes == null)
              IgnorePointer(
                child: Center(
                  child: Text(
                    '당신의 문장을 읽고 있어요…',
                    style: ScriptFonts.styleFor(
                      _languageTag,
                      base: const TextStyle(
                          fontSize: 20, color: Palette.inkFaded),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 4,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    tooltip: '한 획 지우기',
                    onPressed: _writing.hasInk ? _writing.undoStroke : null,
                    icon: const Icon(Icons.undo, color: Palette.inkFaded),
                  ),
                  IconButton(
                    tooltip: '모두 지우기',
                    onPressed: _writing.hasInk ? _writing.clear : null,
                    icon: const Icon(Icons.layers_clear_outlined,
                        color: Palette.inkFaded),
                  ),
                  IconButton(
                    tooltip: '대화 보기',
                    onPressed: () => setState(() => _writingMode = false),
                    icon: const Icon(Icons.chat_bubble_outline,
                        color: Palette.inkFaded),
                  ),
                ],
              ),
            ),
            if (idleEmpty)
              IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _emptyPrompt(),
                          textAlign: TextAlign.center,
                          style: ScriptFonts.styleFor(
                            _languageTag,
                            base: const TextStyle(
                                fontSize: 25,
                                color: Palette.inkFaded,
                                height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '마침표(.)를 찍거나 두 번 톡톡 치면 답장이 와요',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildThread() {
    return ListenableBuilder(
      key: const ValueKey('thread'),
      listenable: _session,
      builder: (context, _) {
        return StreamBuilder<List<ChatMessage>>(
          stream: _session.messageStream,
          builder: (context, snapshot) {
            final messages = snapshot.data ?? const <ChatMessage>[];
            if (messages.isEmpty && _session.status == AiStatus.idle) {
              return Center(
                child: Text('아직 나눈 이야기가 없어요',
                    style: Theme.of(context).textTheme.bodySmall),
              );
            }
            final prefs = ref.watch(writingPrefsProvider);
            return ChatThread(
              messages: messages,
              languageTag: _languageTag,
              status: _session.status,
              lastError: _session.lastError,
              aiTextStyle: ScriptFonts.replyStyle(
                _languageTag,
                prefs.replyFont,
                base: TextStyle(
                  fontSize: 19 *
                      prefs.replyScale *
                      ScriptFonts.scaleFor(_languageTag) /
                      1.2,
                  color: Palette.sage,
                  height: 1.5,
                ),
              ),
              onRetry: _session.requestAiReply,
              onOpenSettings: () => Navigator.of(context).push(
                PageTurnRoute(builder: (_) => const SettingsScreen()),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecognitionBar() {
    return ListenableBuilder(
      listenable: _writing,
      builder: (context, _) {
        final text = _writing.recognizedText;
        // 쓴 게 없을 때는 완전히 숨긴다 — 빈 종이의 감성을 지키기 위해.
        if (!_writing.hasInk && text.isEmpty) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: const BoxDecoration(
            color: Palette.creamDark,
            border: Border(top: BorderSide(color: Palette.ruleLine)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: text.isEmpty ? null : _editRecognizedText,
                  child: Text(
                    text.isEmpty ? '…' : text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.isEmpty
                        ? Theme.of(context).textTheme.bodySmall
                        : Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              IconButton(
                tooltip: '보내기',
                onPressed:
                    (_writing.hasInk || text.isNotEmpty) ? _send : null,
                icon: const Icon(Icons.send_rounded),
                color: Palette.terracotta,
              ),
            ],
          ),
        );
      },
    );
  }

  /// 오늘의 질문 — 무엇을 써야 할지 모르는 날을 위해, 날짜에 따라 돌아간다.
  static const _dailyQuestions = [
    '오늘은 어떤 이야기를\n남기고 싶나요?',
    '오늘 가장 오래\n마음에 남은 순간은?',
    '아무에게도\n하지 못한 말은?',
    '오늘의 나에게\n답장을 쓴다면?',
    '지금 가장 피하고 싶은\n감정은 무엇인가요?',
    '한 달 뒤의 내가 오늘의 나에게\n해줄 말은?',
    '오늘 스쳐 지나간\n작은 다행 하나는?',
  ];

  String _emptyPrompt() {
    if (widget.entry.kind == EntryKind.memo) return '무엇이든 끄적여 보세요';
    if (widget.entry.kind == EntryKind.idea) return '떠오르는 생각을\n그리거나 적어보세요';
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year))
        .inDays;
    return _dailyQuestions[dayOfYear % _dailyQuestions.length];
  }

  static const _sentenceBreak = r'(?<=[.!?…。])\s+';

  /// 답장을 손글씨 쪽지처럼 짧은 줄들로 나눈다.
  static List<String> splitNoteLines(String text) {
    final segments = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final lines = <String>[];
    for (final segment in segments) {
      if (segment.characters.length <= 30) {
        lines.add(segment);
        continue;
      }
      for (final part in segment.split(RegExp(_sentenceBreak))) {
        if (part.trim().isNotEmpty) lines.add(part.trim());
      }
    }
    return lines.isEmpty ? [text] : lines;
  }

  Future<void> _editRecognizedText() async {
    final controller = TextEditingController(text: _writing.recognizedText);
    try {
      await _showEditDialog(controller);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showEditDialog(TextEditingController controller) async {
    final edited = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.cream,
        title: const Text('인식된 글 고치기'),
        content: TextField(controller: controller, maxLines: 4, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.terracotta),
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (edited != null) _writing.editRecognizedText(edited);
  }
}
