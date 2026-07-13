import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_diary/data/models/stroke.dart';
import 'package:secret_diary/features/writing/canvas/handwriting_canvas.dart';

void main() {
  testWidgets('드래그하면 획이 기록된다', (tester) async {
    final strokes = <DiaryStroke>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HandwritingCanvas(
            strokes: const [],
            onStrokeEnd: strokes.add,
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(100, 100));
    await gesture.moveTo(const Offset(140, 120));
    await gesture.moveTo(const Offset(180, 160));
    await gesture.up();
    await tester.pump();

    expect(strokes, hasLength(1));
    expect(strokes.single.points.length, greaterThanOrEqualTo(3));
    expect(strokes.single.points.first.x, 100);
    expect(strokes.single.points.first.y, 100);
    // 터치 입력은 필압 0.5 고정.
    expect(strokes.single.points.every((p) => p.pressure == 0.5), isTrue);
  });

  testWidgets('빠르게 두 번 톡톡 치면 더블터치 신호가 온다', (tester) async {
    final strokes = <DiaryStroke>[];
    var doubleTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HandwritingCanvas(
            strokes: const [],
            onStrokeEnd: strokes.add,
            onDoubleTap: () => doubleTaps++,
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(const Offset(205, 302));
    await tester.pump();

    expect(doubleTaps, 1);
    // 첫 톡은 잉크(마침표 점)로 남고, 두 번째 톡은 신호로만 쓰인다.
    expect(strokes, hasLength(1));
  });

  testWidgets('느리게 두 번 치면 그냥 점 두 개다', (tester) async {
    final strokes = <DiaryStroke>[];
    var doubleTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HandwritingCanvas(
            strokes: const [],
            onStrokeEnd: strokes.add,
            onDoubleTap: () => doubleTaps++,
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tapAt(const Offset(205, 302));
    await tester.pump();

    expect(doubleTaps, 0);
    expect(strokes, hasLength(2));
  });

  testWidgets('두 번 그으면 획 두 개', (tester) async {
    final strokes = <DiaryStroke>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => HandwritingCanvas(
              strokes: List.of(strokes),
              onStrokeEnd: (s) => setState(() => strokes.add(s)),
            ),
          ),
        ),
      ),
    );

    await tester.timedDrag(
      find.byType(HandwritingCanvas),
      const Offset(60, 0),
      const Duration(milliseconds: 100),
    );
    await tester.pump();
    await tester.timedDrag(
      find.byType(HandwritingCanvas),
      const Offset(0, 60),
      const Duration(milliseconds: 100),
    );
    await tester.pump();

    expect(strokes, hasLength(2));
  });
}
