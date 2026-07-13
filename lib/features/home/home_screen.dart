import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/script_fonts.dart';
import '../../core/widgets/ink_fade_in.dart';
import '../../core/widgets/paper_background.dart';
import '../../data/models/diary_entry.dart';
import '../../providers.dart';
import '../settings/language_model_sheet.dart';
import '../settings/settings_screen.dart';
import '../writing/writing_screen.dart';
import 'entry_card.dart';

final _entriesProvider = StreamProvider<List<DiaryEntry>>(
  (ref) => ref.watch(diaryRepositoryProvider).watchEntries(),
);

/// 시작 시 설정에서 언어와 답장 취향을 불러온다.
final _startupProvider = FutureProvider<void>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  final tag = await settings.getLanguageTag();
  ref.read(languageTagProvider.notifier).state = tag;
  ref.read(writingPrefsProvider.notifier).state =
      await settings.getWritingPrefs();
});

/// 홈: 지난 일기 타임라인.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _openToday(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(diaryRepositoryProvider);
    final languageTag = ref.read(languageTagProvider);

    // 언어 모델이 준비됐는지 먼저 확인 (첫 실행 UX).
    // 모델 확인/다운로드가 실패해도 일기 작성 자체는 막지 않는다 —
    // 인식만 안 될 뿐 잉크는 저장된다.
    try {
      await ensureLanguageModel(
          context, ref.read(recognizerProvider), languageTag);
    } catch (_) {}
    if (!context.mounted) return;

    // 오늘 이미 쓰던 일기가 있으면 이어서, 없으면 새로 만든다.
    final latest = await repo.latestEntry();
    final now = DateTime.now();
    DiaryEntry? today;
    if (latest != null &&
        latest.updatedAt.year == now.year &&
        latest.updatedAt.month == now.month &&
        latest.updatedAt.day == now.day) {
      today = latest;
    }
    today ??= await repo.createEntry(languageTag: languageTag);

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WritingScreen(entry: today!)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(_startupProvider);
    final entriesAsync = ref.watch(_entriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '비밀 일기',
          style: ScriptFonts.styleFor(
            'ko',
            base: const TextStyle(fontSize: 30, color: Palette.ink),
          ),
        ),
        actions: [
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: PaperBackground(
        child: entriesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Palette.terracotta),
          ),
          error: (e, _) => Center(
            child: Text('일기를 불러오지 못했어요',
                style: theme.textTheme.bodyMedium),
          ),
          data: (entries) => entries.isEmpty
              ? _EmptyState(theme: theme)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return InkFadeIn(
                      delay: Duration(milliseconds: 40 * index.clamp(0, 8)),
                      child: EntryCard(
                        entry: entry,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WritingScreen(entry: entry),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openToday(context, ref),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('오늘 일기 쓰기'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('M월 d일', 'ko').format(DateTime.now());
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            today,
            style: ScriptFonts.styleFor(
              'ko',
              base: const TextStyle(fontSize: 34, color: Palette.terracotta),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '오늘 마음속 이야기를\n손으로 적어보세요',
            textAlign: TextAlign.center,
            style: ScriptFonts.styleFor(
              'ko',
              base: const TextStyle(
                  fontSize: 24, color: Palette.inkFaded, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
