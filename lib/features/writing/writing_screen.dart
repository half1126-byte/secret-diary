import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/script_fonts.dart';
import '../../core/widgets/paper_background.dart';
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
      duration: const Duration(milliseconds: 1400),
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

    // 1) 방금 쓴 잉크가 종이에 스며들 듯 사라진다.
    setState(() {
      _replyReveal = null;
      _fadingStrokes = snapshot.strokes;
    });
    _fadeController.forward(from: 0);

    // 2) 저장 + AI 답장 요청.
    await _session.sendUserMessage(
      text: snapshot.text,
      strokes: snapshot.strokes,
    );
    if (!mounted) return;

    if (_session.status == AiStatus.failed) {
      // 오류는 대화 화면의 카드(재시도/안내)로 보여준다.
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
    final languageName =
        ScriptFonts.supportedLanguages[_languageTag] ?? _languageTag;

    return Scaffold(
      appBar: AppBar(
        title: Text(dateLabel, style: Theme.of(context).textTheme.titleMedium),
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
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: PaperBackground(
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
            // 전송된 잉크가 종이에 스며들며 사라지는 레이어.
            if (_fadingStrokes != null)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _fadeController,
                  builder: (context, _) => Opacity(
                    opacity: 1 - Curves.easeIn.transform(_fadeController.value),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: StrokesPainter(
                        strokes: _fadingStrokes!,
                        color: Palette.ink,
                      ),
                    ),
                  ),
                ),
              ),
            // AI 답장이 화면 가운데에서 손글씨로 한 글자씩 피어나는 레이어.
            if (_replyReveal != null)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _revealController,
                  builder: (context, _) {
                    final chars = _replyReveal!.characters;
                    final count =
                        (chars.length * _revealController.value).round();
                    return Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          chars.take(count).toString(),
                          textAlign: TextAlign.center,
                          style: ScriptFonts.replyStyle(
                            _languageTag,
                            prefs.replyFont,
                            base: TextStyle(
                              fontSize: 22 *
                                  prefs.replyScale *
                                  ScriptFonts.scaleFor(_languageTag) /
                                  1.2,
                              color: Palette.sage,
                              height: 1.9,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            // 답장을 기다리는 동안의 낮은 숨소리.
            if (_session.status == AiStatus.thinking &&
                !_writing.hasInk &&
                _fadingStrokes == null)
              IgnorePointer(
                child: Center(
                  child: Text(
                    '일기 친구가 펜을 들었어요…',
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '여기에 마음껏 적어보세요',
                        style: ScriptFonts.styleFor(
                          _languageTag,
                          base: const TextStyle(
                              fontSize: 26, color: Palette.inkFaded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '마침표(.)를 찍거나 두 번 톡톡 치면 답장이 와요',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
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
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: const BoxDecoration(
            color: Palette.creamDark,
            border: Border(top: BorderSide(color: Palette.ruleLine)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _writing.recognizing
                    ? Text('읽는 중…',
                        style: Theme.of(context).textTheme.bodySmall)
                    : GestureDetector(
                        onTap: text.isEmpty ? null : _editRecognizedText,
                        child: Text(
                          text.isEmpty
                              ? (_writing.hasInk
                                  ? '손글씨를 읽고 있어요'
                                  : '쓰면 여기에 글자가 나타나요')
                              : text,
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
