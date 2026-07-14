import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import '../../../data/models/stroke.dart';

/// perfect_freehand 잉크 옵션. 필압에 따라 굵기가 변하는 만년필 느낌.
StrokeOptions inkOptions({
  double size = 4.5,
  required bool simulatePressure,
  bool isComplete = true,
}) {
  return StrokeOptions(
    size: size,
    thinning: 0.55,
    smoothing: 0.6,
    streamline: 0.45,
    simulatePressure: simulatePressure,
    isComplete: isComplete,
  );
}

/// 획 하나를 잉크 외곽선 Path로 변환한다.
Path strokeToPath(
  DiaryStroke stroke, {
  double size = 4.5,
  bool isComplete = true,
}) {
  if (stroke.points.isEmpty) return Path();

  // 필압이 사실상 일정하면(손가락) perfect_freehand가 속도 기반으로
  // 자연스러운 굵기 변화를 시뮬레이션하게 한다.
  final pressures = stroke.points.map((p) => p.pressure).toSet();
  final simulate = pressures.length <= 1;

  final outline = getStroke(
    [for (final p in stroke.points) PointVector(p.x, p.y, p.pressure)],
    options: inkOptions(
      size: size,
      simulatePressure: simulate,
      isComplete: isComplete,
    ),
  );

  final path = Path();
  if (outline.isEmpty) return path;
  if (outline.length < 2) {
    // 점 하나: 작은 원.
    path.addOval(Rect.fromCircle(center: outline[0], radius: size / 2));
    return path;
  }

  path.moveTo(outline[0].dx, outline[0].dy);
  for (var i = 1; i < outline.length - 1; i++) {
    final p0 = outline[i];
    final p1 = outline[i + 1];
    path.quadraticBezierTo(
        p0.dx, p0.dy, (p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
  }
  path.close();
  return path;
}

/// 전송된 잉크가 획 하나하나 번지며 종이에 스며드는 페인터.
///
/// 각 획은 [delays]의 자기 몫만큼 기다렸다가, 흐려지고(blur) 옅어지며
/// 사라진다 — 잉크가 종이에 배어드는 느낌.
class DissolvingStrokesPainter extends CustomPainter {
  DissolvingStrokesPainter({
    required this.strokes,
    required this.delays,
    required this.progress,
    required this.color,
    this.strokeSize = 4.5,
  });

  final List<DiaryStroke> strokes;

  /// 획별 시작 지연 (0~1 진행률 기준). strokes와 길이가 같아야 한다.
  final List<double> delays;

  /// 전체 진행률 0~1.
  final double progress;

  final Color color;
  final double strokeSize;

  /// 각 획이 사라지는 데 쓰는 구간 길이.
  static const _span = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < strokes.length; i++) {
      final delay = i < delays.length ? delays[i] : 0.0;
      final local = ((progress - delay) / _span).clamp(0.0, 1.0);
      if (local >= 1.0) continue; // 이미 스며들었다.
      final eased = Curves.easeIn.transform(local);
      final paint = Paint()..color = color.withValues(alpha: 1.0 - eased);
      if (eased > 0) {
        // 번짐: 사라질수록 잉크가 퍼진다.
        paint.maskFilter =
            MaskFilter.blur(BlurStyle.normal, 0.5 + eased * 7);
      }
      canvas.drawPath(strokeToPath(strokes[i], size: strokeSize), paint);
    }
  }

  @override
  bool shouldRepaint(DissolvingStrokesPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.strokes != strokes;
}

/// 여러 획을 그리는 페인터. 캔버스와 썸네일 양쪽에서 재사용한다.
class StrokesPainter extends CustomPainter {
  StrokesPainter({
    required this.strokes,
    required this.color,
    this.strokeSize = 4.5,
    this.fit = false,
    this.padding = 4,
  });

  final List<DiaryStroke> strokes;
  final Color color;
  final double strokeSize;

  /// true면 획 전체를 캔버스 크기에 맞춰 축소해 그린다 (썸네일).
  final bool fit;

  final double padding;

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;
    final paint = Paint()..color = color;

    if (fit) {
      final availW = size.width - padding * 2;
      final availH = size.height - padding * 2;
      if (availW <= 0 || availH <= 0) return;
      final box = StrokeCodec.boundingBox(strokes);
      final w = box.width == 0 ? 1.0 : box.width;
      final h = box.height == 0 ? 1.0 : box.height;
      final scale = math.min(availW / w, availH / h);
      final dx = (size.width - w * scale) / 2 - box.left * scale;
      final dy = (size.height - h * scale) / 2 - box.top * scale;
      canvas.translate(dx, dy);
      canvas.scale(scale);
    }

    for (final stroke in strokes) {
      canvas.drawPath(strokeToPath(stroke, size: strokeSize), paint);
    }
  }

  @override
  bool shouldRepaint(StrokesPainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.color != color ||
      oldDelegate.strokeSize != strokeSize ||
      oldDelegate.fit != fit;
}
