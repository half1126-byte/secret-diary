import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:secret_diary/data/models/stroke.dart';

void main() {
  group('StrokeCodec', () {
    test('인코딩-디코딩 라운드트립이 값을 보존한다', () {
      final strokes = [
        const DiaryStroke(points: [
          DiaryPoint(x: 10.14, y: 20.26, pressure: 0.5, t: 0),
          DiaryPoint(x: 11.9, y: 21.1, pressure: 0.8, t: 16),
        ]),
        const DiaryStroke(points: [
          DiaryPoint(x: 100, y: 200, pressure: 1, t: 500),
        ]),
      ];

      final decoded = StrokeCodec.decode(StrokeCodec.encode(strokes));

      expect(decoded, hasLength(2));
      expect(decoded[0].points, hasLength(2));
      // 소수 1자리 반올림.
      expect(decoded[0].points[0].x, 10.1);
      expect(decoded[0].points[0].y, 20.3);
      expect(decoded[0].points[1].pressure, 0.8);
      expect(decoded[0].points[1].t, 16);
      expect(decoded[1].points[0].x, 100);
    });

    test('빈 목록도 처리한다', () {
      expect(StrokeCodec.decode(StrokeCodec.encode([])), isEmpty);
    });

    test('boundingBox가 전체 획을 감싼다', () {
      final strokes = [
        const DiaryStroke(points: [
          DiaryPoint(x: 10, y: 5, pressure: 0.5, t: 0),
          DiaryPoint(x: 30, y: 40, pressure: 0.5, t: 1),
        ]),
        const DiaryStroke(points: [
          DiaryPoint(x: 2, y: 8, pressure: 0.5, t: 2),
        ]),
      ];

      expect(StrokeCodec.boundingBox(strokes), const Rect.fromLTRB(2, 5, 30, 40));
      expect(StrokeCodec.boundingBox([]), Rect.zero);
    });
  });
}
