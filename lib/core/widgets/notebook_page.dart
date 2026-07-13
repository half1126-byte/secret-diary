import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// 가죽 위에 놓인 낡은 종이 묶음.
///
/// 해진(찢긴) 가장자리의 맨 윗장 아래로 밑장들이 살짝 어긋나 보이고,
/// 그 전체가 어두운 가죽 표지 위에 놓여 있다 — 전부 코드로 그린다.
class NotebookPage extends StatelessWidget {
  const NotebookPage({
    super.key,
    required this.child,
    this.showRuleLines = false,
    this.ruleLineSpacing = 44,
  });

  final Widget child;
  final bool showRuleLines;
  final double ruleLineSpacing;

  /// 맨 윗장 안쪽으로 콘텐츠가 들어갈 여백.
  static const contentInset = EdgeInsets.fromLTRB(20, 18, 22, 22);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NotebookPainter(
        showRuleLines: showRuleLines,
        ruleLineSpacing: ruleLineSpacing,
      ),
      child: Padding(padding: contentInset, child: child),
    );
  }
}

class _NotebookPainter extends CustomPainter {
  _NotebookPainter({
    required this.showRuleLines,
    required this.ruleLineSpacing,
  });

  final bool showRuleLines;
  final double ruleLineSpacing;

  /// 해진 가장자리 사각형 경로.
  static Path _tornRect(Rect rect, Random random, {double amp = 3.5}) {
    final path = Path();
    const step = 15.0;
    Offset jitter(Offset p, double nx, double ny) {
      var a = (random.nextDouble() - 0.5) * 2 * amp;
      // 가끔 크게 뜯긴 자국.
      if (random.nextInt(18) == 0) a -= random.nextDouble() * 7;
      return Offset(p.dx + nx * a, p.dy + ny * a);
    }

    var first = true;
    void walk(Offset from, Offset to, double nx, double ny) {
      final length = (to - from).distance;
      final steps = max(1, (length / step).floor());
      for (var i = 0; i <= steps; i++) {
        final p = Offset.lerp(from, to, i / steps)!;
        final q = (i == 0 || i == steps) ? p : jitter(p, nx, ny);
        if (first) {
          path.moveTo(q.dx, q.dy);
          first = false;
        } else {
          path.lineTo(q.dx, q.dy);
        }
      }
    }

    // 안쪽을 향하는 법선 방향으로 요철을 준다.
    walk(rect.topLeft, rect.topRight, 0, 1);
    walk(rect.topRight, rect.bottomRight, -1, 0);
    walk(rect.bottomRight, rect.bottomLeft, 0, -1);
    walk(rect.bottomLeft, rect.topLeft, 1, 0);
    path.close();
    return path;
  }

  void _paintLeather(Canvas canvas, Rect full, Random random) {
    canvas.drawRect(full, Paint()..color = const Color(0xFF4A3521));
    // 가장자리로 갈수록 어두운 그늘.
    canvas.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          radius: 1.2,
          colors: const [Color(0x00000000), Color(0x59120A04)],
          stops: const [0.5, 1.0],
        ).createShader(full),
    );
    // 가죽 결 스크래치.
    final scratch = Paint()
      ..color = const Color(0x168B6A48)
      ..strokeWidth = 0.8;
    for (var i = 0; i < 46; i++) {
      final x = random.nextDouble() * full.width;
      final y = random.nextDouble() * full.height;
      final len = random.nextDouble() * 26 + 6;
      final angle = random.nextDouble() * pi;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + cos(angle) * len, y + sin(angle) * len),
        scratch,
      );
    }
  }

  void _paintPageTexture(Canvas canvas, Rect page, Random random) {
    // 세월의 얼룩.
    final stain = Paint()..color = Palette.stain;
    for (var i = 0; i < 6; i++) {
      final cx = page.left + random.nextDouble() * page.width;
      final cy = page.top + random.nextDouble() * page.height;
      for (var b = 0; b < 4; b++) {
        canvas.drawCircle(
          Offset(cx + (random.nextDouble() - 0.5) * 40,
              cy + (random.nextDouble() - 0.5) * 40),
          random.nextDouble() * 30 + 14,
          stain,
        );
      }
    }
    // 종이 섬유.
    final fiber = Paint()
      ..color = Palette.fiber
      ..strokeWidth = 0.7;
    for (var i = 0; i < 180; i++) {
      final x = page.left + random.nextDouble() * page.width;
      final y = page.top + random.nextDouble() * page.height;
      final len = random.nextDouble() * 9 + 4;
      final angle = random.nextDouble() * pi;
      canvas.drawLine(Offset(x, y),
          Offset(x + cos(angle) * len, y + sin(angle) * len), fiber);
    }
    // 반점.
    final speckle = Paint()..color = Palette.speckle;
    final count = (page.width * page.height / 1000).clamp(60, 1800).toInt();
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(
        Offset(page.left + random.nextDouble() * page.width,
            page.top + random.nextDouble() * page.height),
        random.nextDouble() * 1.3 + 0.3,
        speckle,
      );
    }

    if (showRuleLines) {
      final line = Paint()
        ..color = Palette.ruleLine
        ..strokeWidth = 1;
      for (var y = page.top + ruleLineSpacing * 2;
          y < page.bottom - 14;
          y += ruleLineSpacing) {
        canvas.drawLine(Offset(page.left + 14, y),
            Offset(page.right - 14, y), line);
      }
    }

    // 페이지 가장자리 그늘.
    canvas.drawRect(
      page,
      Paint()
        ..shader = RadialGradient(
          radius: 1.1,
          colors: const [Color(0x00000000), Palette.vignette],
          stops: const [0.6, 1.0],
        ).createShader(page),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final random = Random(20260713);

    _paintLeather(canvas, full, random);

    // 2) 밑장들 — 살짝 어긋나고 미묘하게 다른 톤.
    const tones = [Color(0xFFDCC69B), Color(0xFFE5D2A9), Color(0xFFECDBB6)];
    const offsets = [Offset(7, 11), Offset(4, 7), Offset(2, 3.5)];
    final baseRect = Rect.fromLTRB(10, 8, size.width - 12, size.height - 12);
    for (var i = 0; i < tones.length; i++) {
      final r = baseRect.shift(offsets[i]);
      final path = _tornRect(r, random, amp: 3);
      canvas.drawShadow(path, const Color(0xB3000000), 3, false);
      canvas.drawPath(path, Paint()..color = tones[i]);
    }

    // 3) 맨 윗장 — 해진 가장자리 + 질감.
    final topPath = _tornRect(baseRect, random, amp: 4);
    canvas.drawShadow(topPath, const Color(0xCC000000), 4, false);
    canvas.drawPath(topPath, Paint()..color = Palette.cream);
    // 해진 단면의 어두운 테.
    canvas.drawPath(
      topPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0x33876F45),
    );

    canvas.save();
    canvas.clipPath(topPath);
    _paintPageTexture(canvas, baseRect, random);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NotebookPainter oldDelegate) =>
      oldDelegate.showRuleLines != showRuleLines ||
      oldDelegate.ruleLineSpacing != ruleLineSpacing;
}
