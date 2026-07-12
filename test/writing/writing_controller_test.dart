import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_diary/data/models/stroke.dart';
import 'package:secret_diary/features/writing/writing_controller.dart';
import 'package:secret_diary/services/handwriting/fake_recognizer.dart';

DiaryStroke stroke([double offset = 0]) => DiaryStroke(points: [
      DiaryPoint(x: offset, y: 0, pressure: 0.5, t: 0),
      DiaryPoint(x: offset + 10, y: 10, pressure: 0.5, t: 16),
    ]);

void main() {
  test('획 추가 후 디바운스가 지나면 인식이 실행된다', () {
    fakeAsync((async) {
      final recognizer = FakeRecognizer(result: '안녕');
      final controller = WritingController(
        recognizer: recognizer,
        languageTag: 'ko',
      );

      controller.addStroke(stroke());
      expect(recognizer.recognizeCalls, 0);

      async.elapse(const Duration(milliseconds: 1300));
      expect(recognizer.recognizeCalls, 1);
      expect(recognizer.lastLanguageTag, 'ko');
      expect(controller.recognizedText, '안녕');
      expect(controller.recognizing, isFalse);
    });
  });

  test('연속으로 그리는 동안은 인식을 미룬다', () {
    fakeAsync((async) {
      final recognizer = FakeRecognizer();
      final controller = WritingController(
        recognizer: recognizer,
        languageTag: 'ko',
      );

      controller.addStroke(stroke());
      async.elapse(const Duration(milliseconds: 800));
      controller.addStroke(stroke(20));
      async.elapse(const Duration(milliseconds: 800));
      expect(recognizer.recognizeCalls, 0);

      async.elapse(const Duration(milliseconds: 500));
      expect(recognizer.recognizeCalls, 1);
      expect(recognizer.lastStrokes, hasLength(2));
    });
  });

  test('undo와 clear가 상태를 정리한다', () {
    fakeAsync((async) {
      final controller = WritingController(
        recognizer: FakeRecognizer(),
        languageTag: 'ko',
      );

      controller.addStroke(stroke());
      controller.addStroke(stroke(20));
      controller.undoStroke();
      expect(controller.strokes, hasLength(1));

      controller.undoStroke();
      expect(controller.hasInk, isFalse);
      expect(controller.recognizedText, isEmpty);

      controller.addStroke(stroke());
      controller.clear();
      expect(controller.hasInk, isFalse);
      async.elapse(const Duration(seconds: 2));
    });
  });

  test('수동 편집한 텍스트는 늦게 온 인식 결과가 덮지 않는다', () {
    fakeAsync((async) {
      final recognizer =
          FakeRecognizer(result: '기계 인식', delay: const Duration(seconds: 1));
      final controller = WritingController(
        recognizer: recognizer,
        languageTag: 'ko',
      );

      controller.addStroke(stroke());
      async.elapse(const Duration(milliseconds: 1250)); // 인식 시작(1초 소요)
      controller.editRecognizedText('내가 고친 텍스트');
      async.elapse(const Duration(seconds: 2)); // 인식 완료 시점 경과

      expect(controller.recognizedText, '내가 고친 텍스트');
    });
  });

  test('takeSnapshot이 획과 텍스트를 떼어내고 비운다', () {
    fakeAsync((async) {
      final controller = WritingController(
        recognizer: FakeRecognizer(result: '오늘의 일기'),
        languageTag: 'ko',
      );

      controller.addStroke(stroke());
      async.elapse(const Duration(milliseconds: 1300));

      final snapshot = controller.takeSnapshot();
      expect(snapshot, isNotNull);
      expect(snapshot!.strokes, hasLength(1));
      expect(snapshot.text, '오늘의 일기');
      expect(controller.hasInk, isFalse);
      expect(controller.recognizedText, isEmpty);

      expect(controller.takeSnapshot(), isNull);
    });
  });
}
