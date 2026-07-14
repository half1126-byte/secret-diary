import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// 프로시저럴 종이 질감 배경.
///
/// 이미지 에셋 없이 고정 시드의 반점과 (선택적으로) 흐린 괘선을 그려
/// 오래된 노트 같은 질감을 만든다.
class PaperBackground extends StatelessWidget {
  const PaperBackground({
    super.key,
    required this.child,
    this.showRuleLines = false,
    this.ruleLineSpacing = 44,
  });

  final Widget child;

  /// true면 필기 노트처럼 가로 괘선을 그린다.
  final bool showRuleLines;

  final double ruleLineSpacing;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PaperPainter(
        showRuleLines: showRuleLines,
        ruleLineSpacing: ruleLineSpacing,
      ),
      child: child,
    );
  }
}

class _PaperPainter extends CustomPainter {
  _PaperPainter({required this.showRuleLines, required this.ruleLineSpacing});

  final bool showRuleLines;
  final double ruleLineSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = Palette.cream);

    // 고정 시드 → 스크롤/리페인트에도 질감이 흔들리지 않는다.
    final random = Random(20260712);

    // 1) 세월의 얼룩 — 커피 자국처럼 겹친 원 무리.
    final stain = Paint()..color = Palette.stain;
    final stainCount = (size.width * size.height / 90000).clamp(3, 9).toInt();
    for (var i = 0; i < stainCount; i++) {
      final cx = random.nextDouble() * size.width;
      final cy = random.nextDouble() * size.height;
      final blots = 3 + random.nextInt(3);
      for (var b = 0; b < blots; b++) {
        final dx = cx + (random.nextDouble() - 0.5) * 46;
        final dy = cy + (random.nextDouble() - 0.5) * 46;
        final r = random.nextDouble() * 34 + 16;
        canvas.drawCircle(Offset(dx, dy), r, stain);
      }
    }

    // 2) 종이 섬유 결 — 짧고 흐린 선.
    final fiber = Paint()
      ..color = Palette.fiber
      ..strokeWidth = 0.7;
    final fiberCount = (size.width * size.height / 5500).clamp(30, 340).toInt();
    for (var i = 0; i < fiberCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final len = random.nextDouble() * 10 + 5;
      final angle = random.nextDouble() * pi;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + cos(angle) * len, y + sin(angle) * len),
        fiber,
      );
    }

    // 3) 미세한 반점.
    final speckle = Paint()..color = Palette.speckle;
    final speckleCount = (size.width * size.height / 900).clamp(80, 2200).toInt();
    for (var i = 0; i < speckleCount; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final r = random.nextDouble() * 1.4 + 0.3;
      canvas.drawCircle(Offset(dx, dy), r, speckle);
    }

    if (showRuleLines) {
      final line = Paint()
        ..color = Palette.ruleLine
        ..strokeWidth = 1;
      for (var y = ruleLineSpacing * 2; y < size.height; y += ruleLineSpacing) {
        canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), line);
      }
    }

    // 4) 가장자리 그늘 — 오래 만진 종이의 손때.
    final vignette = Paint()
      ..shader = RadialGradient(
        radius: 1.15,
        colors: [const Color(0x00000000), Palette.vignette],
        stops: const [0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  @override
  bool shouldRepaint(_PaperPainter oldDelegate) =>
      oldDelegate.showRuleLines != showRuleLines ||
      oldDelegate.ruleLineSpacing != ruleLineSpacing;
}
