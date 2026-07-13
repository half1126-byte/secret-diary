import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'coach_app.dart';

/// AI 말풍선을 꾹 누르면 뜨는 공유용 팩폭 카드.
///
/// 카드 이미지를 캡처해 인스타/카톡 등으로 공유한다 — 바이럴 장치.
Future<void> showShareCard(
  BuildContext context, {
  required String quote,
  int? excuseScore,
}) async {
  final boundaryKey = GlobalKey();

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: CoachColors.bg,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: boundaryKey,
            child: _FactBombCard(quote: quote, excuseScore: excuseScore),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: CoachColors.accent,
                ),
                onPressed: () => _share(sheetContext, boundaryKey),
                icon: const Icon(Icons.ios_share),
                label: const Text('팩폭 카드 공유'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<void> _share(BuildContext context, GlobalKey boundaryKey) async {
  try {
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/factbomb.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: '#팩폭상담소'),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유 실패. 이것도 핑계는 아니고 진짜다.')),
      );
    }
  }
}

class _FactBombCard extends StatelessWidget {
  const _FactBombCard({required this.quote, this.excuseScore});

  final String quote;
  final int? excuseScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C2027), Color(0xFF12141A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CoachColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (excuseScore != null) ...[
            _ExcuseStamp(score: excuseScore!),
            const SizedBox(height: 14),
          ],
          Text(
            quote,
            style: const TextStyle(
              color: CoachColors.text,
              fontSize: 19,
              height: 1.55,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: CoachColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '팩폭상담소 — 실행이 답이다',
                style: TextStyle(color: CoachColors.textFaded, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 핑계지수 스탬프 — 도장 찍힌 느낌.
class _ExcuseStamp extends StatelessWidget {
  const _ExcuseStamp({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.06,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: CoachColors.accent, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '핑계지수 $score%',
          style: const TextStyle(
            color: CoachColors.accent,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
