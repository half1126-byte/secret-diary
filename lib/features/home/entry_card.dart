import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/script_fonts.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/diary_entry.dart';
import '../../providers.dart';
import '../writing/canvas/stroke_painter.dart';

/// 타임라인의 일기 카드: 손글씨 폰트 날짜 + 제목 + 잉크 썸네일.
class EntryCard extends ConsumerWidget {
  const EntryCard({super.key, required this.entry, required this.onTap});

  final DiaryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat('M월 d일', 'ko').format(entry.createdAt);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          dateLabel,
                          style: ScriptFonts.styleFor(
                            'ko',
                            base: const TextStyle(
                                fontSize: 22, color: Palette.terracotta),
                          ),
                        ),
                        if (entry.kind != EntryKind.diary) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(
                              border: Border.all(color: Palette.ruleLine),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(entry.kind.label,
                                style: theme.textTheme.bodySmall),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.title ?? '아직 쓰는 중…',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _InkThumbnail(entryId: entry.id),
            ],
          ),
        ),
      ),
    );
  }
}

class _InkThumbnail extends ConsumerWidget {
  const _InkThumbnail({required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<ChatMessage?>(
      future: ref.read(diaryRepositoryProvider).firstUserMessage(entryId),
      builder: (context, snapshot) {
        final strokes = snapshot.data?.strokes;
        if (strokes == null || strokes.isEmpty) {
          return const SizedBox(width: 64, height: 64);
        }
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Palette.cream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.ruleLine),
          ),
          child: CustomPaint(
            painter: StrokesPainter(
              strokes: strokes,
              color: Palette.ink,
              fit: true,
              padding: 8,
            ),
          ),
        );
      },
    );
  }
}
