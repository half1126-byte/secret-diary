import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/navigation/page_turn_route.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/script_fonts.dart';
import '../../core/widgets/paper_background.dart';
import '../../data/models/diary_entry.dart';
import '../../providers.dart';
import '../writing/writing_screen.dart';

/// 달력 — 어떤 날에 어떤 기록(일기/메모/상담/아이디어)이 있는지 한눈에.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  static Color _dotColor(EntryKind kind) => switch (kind) {
        EntryKind.diary => Palette.terracotta,
        EntryKind.memo => Palette.inkFaded,
        EntryKind.counsel => Palette.dusk,
        EntryKind.idea => Palette.sage,
      };

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  Future<void> _openDay(List<DiaryEntry> entries) async {
    if (entries.length == 1) {
      await Navigator.of(context).push(
        PageTurnRoute(builder: (_) => WritingScreen(entry: entries.single)),
      );
      if (mounted) setState(() {});
      return;
    }
    final picked = await showModalBottomSheet<DiaryEntry>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final e in entries)
            ListTile(
              leading: Icon(Icons.circle, size: 10, color: _dotColor(e.kind)),
              title: Text(e.title ?? e.kind.label),
              subtitle: Text(e.kind.label,
                  style: Theme.of(context).textTheme.bodySmall),
              onTap: () => Navigator.of(context).pop(e),
            ),
        ],
      ),
    );
    if (picked != null && mounted) {
      await Navigator.of(context).push(
        PageTurnRoute(builder: (_) => WritingScreen(entry: picked)),
      );
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = ref.read(diaryRepositoryProvider);
    final monthLabel = DateFormat('yyyy년 M월', 'ko').format(_month);
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('달력')),
      body: PaperBackground(
        child: FutureBuilder<Map<int, List<DiaryEntry>>>(
          future: repo.entriesByDayInMonth(_month),
          builder: (context, snapshot) {
            final byDay = snapshot.data ?? const <int, List<DiaryEntry>>{};
            return Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _shiftMonth(-1),
                    ),
                    SizedBox(
                      width: 170,
                      child: Text(
                        monthLabel,
                        textAlign: TextAlign.center,
                        style: ScriptFonts.styleFor(
                          'ko',
                          base: const TextStyle(
                              fontSize: 26, color: Palette.ink),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _shiftMonth(1),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      for (final d in const ['일', '월', '화', '수', '목', '금', '토'])
                        Expanded(
                          child: Center(
                            child: Text(d, style: theme.textTheme.bodySmall),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: firstWeekday + daysInMonth,
                    itemBuilder: (context, index) {
                      if (index < firstWeekday) {
                        return const SizedBox.shrink();
                      }
                      final day = index - firstWeekday + 1;
                      final entries = byDay[day] ?? const <DiaryEntry>[];
                      final isToday = _month.year == now.year &&
                          _month.month == now.month &&
                          day == now.day;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: entries.isEmpty
                            ? null
                            : () => _openDay(entries),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: isToday
                                  ? BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Palette.terracotta,
                                          width: 1.4),
                                    )
                                  : null,
                              child: Text(
                                '$day',
                                style: ScriptFonts.styleFor(
                                  'ko',
                                  base: TextStyle(
                                    fontSize: 19,
                                    color: entries.isEmpty
                                        ? Palette.inkFaded
                                        : Palette.ink,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 10,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final kind in {
                                    for (final e in entries) e.kind
                                  }.take(4))
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 1.5),
                                      child: Icon(Icons.circle,
                                          size: 6, color: _dotColor(kind)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 4),
                  child: Wrap(
                    spacing: 14,
                    children: [
                      for (final kind in EntryKind.values)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle,
                                size: 7, color: _dotColor(kind)),
                            const SizedBox(width: 4),
                            Text(kind.label,
                                style: theme.textTheme.bodySmall),
                          ],
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
