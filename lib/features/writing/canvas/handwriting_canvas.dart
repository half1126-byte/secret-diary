import 'dart:async';

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
    this.onDoubleTap,
    this.inkColor = Palette.ink,
    this.strokeSize = 4.5,
  });

  /// 이미 완성된 획들 (컨트롤러가 관리).
  final List<DiaryStroke> strokes;

  /// 펜을 뗄 때 완성된 획을 전달.
  final ValueChanged<DiaryStroke> onStrokeEnd;

  /// 빠르게 두 번 톡톡 — "내 이야기는 여기까지"라는 신호.
  /// 첫 번째 톡은 잉크(마침표)로 남고, 두 번째 톡은 신호로만 쓰인다.
  final VoidCallback? onDoubleTap;

  final Color inkColor;
  final double strokeSize;

  @override
  State<HandwritingCanvas> createState() => _HandwritingCanvasState();
}

class _HandwritingCanvasState extends State<HandwritingCanvas> {
  final List<DiaryPoint> _activePoints = [];
  int? _activePointer;
  bool _stylusSeen = false;

  /// 첫 이벤트 기준 상대 시각(ms). PointerEvent.timeStamp를 쓰므로
  /// 테스트의 가짜 시계와 실기기의 하드웨어 시계 모두에서 일관된다.
  int? _epochMs;

  int _eventMs(PointerEvent event) {
    final ms = event.timeStamp.inMilliseconds;
    _epochMs ??= ms;
    return ms - _epochMs!;
  }

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
        t: _eventMs(event),
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

  /// 더블터치 인식 창. 이벤트 timeStamp는 테스트 가짜 시계를 따르지 않아
  /// Timer(존 시계 기반)로 창을 연다.
  Timer? _tapWindow;
  Offset? _lastTapPos;

  /// 짧고 작은 획 = 톡(탭). 마침표 점도 여기에 해당한다.
  static bool _looksLikeTap(List<DiaryPoint> points) {
    if (points.isEmpty) return false;
    if (points.last.t - points.first.t > 220) return false;
    final box = StrokeCodec.boundingBox([DiaryStroke(points: points)]);
    return box.width < 14 && box.height < 14;
  }

  void _onEnd(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    final stroke = DiaryStroke(points: List.unmodifiable(_activePoints));
    setState(() {
      _activePointer = null;
      _activePoints.clear();
    });
    if (stroke.points.isEmpty) return;

    if (widget.onDoubleTap != null && _looksLikeTap(stroke.points)) {
      final pos = stroke.points.first.offset;
      if (_tapWindow != null &&
          _tapWindow!.isActive &&
          (_lastTapPos! - pos).distance < 60) {
        // 두 번째 톡: 잉크로 남기지 않고 신호만 보낸다.
        _tapWindow!.cancel();
        _tapWindow = null;
        _lastTapPos = null;
        widget.onDoubleTap!();
        return;
      }
      _tapWindow?.cancel();
      _tapWindow = Timer(const Duration(milliseconds: 400), () {});
      _lastTapPos = pos;
    } else {
      _tapWindow?.cancel();
      _tapWindow = null;
      _lastTapPos = null;
    }

    widget.onStrokeEnd(stroke);
  }

  @override
  void dispose() {
    _tapWindow?.cancel();
    super.dispose();
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
