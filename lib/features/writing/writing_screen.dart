import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/script_fonts.dart';
import '../../core/widgets/paper_background.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/diary_entry.dart';
import '../../providers.dart';
import '../settings/language_model_sheet.dart';
import '../settings/settings_screen.dart';
import 'canvas/handwriting_canvas.dart';
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

class _WritingScreenState extends ConsumerState<WritingScreen> {
  late WritingController _writing;
  late EntrySession _session;
  late String _languageTag;

  /// true = 캔버스 모드, false = 대화 모드.
  bool _writingMode = true;

  String _sentText = '';

  @override
  void initState() {
    super.initState();
    _languageTag = widget.entry.languageTag;
    _writing = WritingController(
      recognizer: ref.read(recognizerProvider),
      languageTag: _languageTag,
      preContextProvider: () => _sentText,
    );
    _session = EntrySession(
      repository: ref.read(diaryRepositoryProvider),
      settings: ref.read(settingsRepositoryProvider),
      gemini: ref.read(geminiClientProvider),
      entryId: widget.entry.id,
    );
  }

  @override
  void dispose() {
    _writing.dispose();
    _session.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final snapshot = _writing.takeSnapshot();
    if (snapshot == null) return;
    _sentText = '$_sentText ${snapshot.text}'.trim();
    setState(() => _writingMode = false);
    await _session.sendUserMessage(
      text: snapshot.text,
      strokes: snapshot.strokes,
    );
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
    return ListenableBuilder(
      key: const ValueKey('canvas'),
      listenable: _writing,
      builder: (context, _) {
        return Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                _writing.writingArea = constraints.biggest;
                return HandwritingCanvas(
                  strokes: _writing.strokes,
                  onStrokeEnd: _writing.addStroke,
                );
              },
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
            if (!_writing.hasInk)
              IgnorePointer(
                child: Center(
                  child: Text(
                    '여기에 마음껏 적어보세요',
                    style: ScriptFonts.styleFor(
                      _languageTag,
                      base: const TextStyle(
                          fontSize: 26, color: Palette.inkFaded),
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
            return ChatThread(
              messages: messages,
              languageTag: _languageTag,
              status: _session.status,
              lastError: _session.lastError,
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
