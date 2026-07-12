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
    final background = Paint()..color = Palette.cream;
    canvas.drawRect(Offset.zero & size, background);

    // 고정 시드 → 스크롤/리페인트에도 질감이 흔들리지 않는다.
    final random = Random(20260712);
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
  }

  @override
  bool shouldRepaint(_PaperPainter oldDelegate) =>
      oldDelegate.showRuleLines != showRuleLines ||
      oldDelegate.ruleLineSpacing != ruleLineSpacing;
}
