import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/palette.dart';
import '../../../data/models/stroke.dart';
import 'stroke_painter.dart';

/// 손글씨 입력 캔버스.
///
/// - `Listener` 기반 포인터 캡처: 필압(`PointerEvent.pressure`)과
///   스타일러스 여부를 읽는다 (GestureDetector는 필압을 주지 않음).
/// - 팜 리젝션: 스타일러스가 한 번이라도 감지되면 이후 터치 입력은 무시.
/// - 완성된 획은 [onStrokeEnd]로 부모(컨트롤러)에 전달되는 단방향 구조.
class HandwritingCanvas extends StatefulWidget {
  const HandwritingCanvas({
    super.key,
    required this.strokes,
    required this.onStrokeEnd,
    this.inkColor = Palette.ink,
    this.strokeSize = 4.5,
  });

  /// 이미 완성된 획들 (컨트롤러가 관리).
  final List<DiaryStroke> strokes;

  /// 펜을 뗄 때 완성된 획을 전달.
  final ValueChanged<DiaryStroke> onStrokeEnd;

  final Color inkColor;
  final double strokeSize;

  @override
  State<HandwritingCanvas> createState() => _HandwritingCanvasState();
}

class _HandwritingCanvasState extends State<HandwritingCanvas> {
  final List<DiaryPoint> _activePoints = [];
  int? _activePointer;
  bool _stylusSeen = false;
  final Stopwatch _clock = Stopwatch()..start();

  bool _acceptPointer(PointerEvent event) {
    if (event.kind == PointerDeviceKind.stylus) {
      _stylusSeen = true;
      return true;
    }
    // 스타일러스를 쓰기 시작했다면 손바닥(터치)은 무시.
    if (_stylusSeen && event.kind == PointerDeviceKind.touch) return false;
    return event.kind == PointerDeviceKind.touch ||
        event.kind == PointerDeviceKind.mouse ||
        event.kind == PointerDeviceKind.invertedStylus;
  }

  double _normalizedPressure(PointerEvent event) {
    if (event.kind != PointerDeviceKind.stylus &&
        event.kind != PointerDeviceKind.invertedStylus) {
      return 0.5;
    }
    final range = event.pressureMax - event.pressureMin;
    if (range <= 0) return 0.5;
    return ((event.pressure - event.pressureMin) / range).clamp(0.0, 1.0);
  }

  DiaryPoint _toPoint(PointerEvent event) => DiaryPoint(
        x: event.localPosition.dx,
        y: event.localPosition.dy,
        pressure: _normalizedPressure(event),
        t: _clock.elapsedMilliseconds,
      );

  void _onDown(PointerDownEvent event) {
    if (_activePointer != null || !_acceptPointer(event)) return;
    setState(() {
      _activePointer = event.pointer;
      _activePoints
        ..clear()
        ..add(_toPoint(event));
    });
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    setState(() => _activePoints.add(_toPoint(event)));
  }

  void _onEnd(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    final stroke = DiaryStroke(points: List.unmodifiable(_activePoints));
    setState(() {
      _activePointer = null;
      _activePoints.clear();
    });
    if (stroke.points.isNotEmpty) widget.onStrokeEnd(stroke);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onEnd,
      onPointerCancel: _onEnd,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 완성된 획 레이어 — 획이 추가될 때만 다시 그린다.
          RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              willChange: false,
              painter: StrokesPainter(
                strokes: widget.strokes,
                color: widget.inkColor,
                strokeSize: widget.strokeSize,
              ),
            ),
          ),
          // 지금 그리는 획 레이어 — 포인터 이벤트마다 다시 그린다.
          CustomPaint(
            painter: _ActiveStrokePainter(
              points: List.of(_activePoints),
              color: widget.inkColor,
              strokeSize: widget.strokeSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveStrokePainter extends CustomPainter {
  _ActiveStrokePainter({
    required this.points,
    required this.color,
    required this.strokeSize,
  });

  final List<DiaryPoint> points;
  final Color color;
  final double strokeSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()..color = color;
    canvas.drawPath(
      strokeToPath(
        DiaryStroke(points: points),
        size: strokeSize,
        isComplete: false,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ActiveStrokePainter oldDelegate) =>
      oldDelegate.points.length != points.length ||
      oldDelegate.color != color;
}
