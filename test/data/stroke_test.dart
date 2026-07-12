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

    test('NaN/Infinity 좌표가 있어도 항상 디코딩 가능한 JSON을 만든다', () {
      final strokes = [
        const DiaryStroke(points: [
          DiaryPoint(x: double.nan, y: 10, pressure: 0.5, t: 0),
          DiaryPoint(x: 5, y: double.infinity, pressure: 0.5, t: 1),
          DiaryPoint(x: 5, y: 6, pressure: double.nan, t: 2),
          DiaryPoint(x: 7, y: 8, pressure: 0.9, t: 3),
        ]),
      ];

      // encode가 invalid JSON을 만들지 않고, decode가 성공해야 한다.
      final decoded = StrokeCodec.decode(StrokeCodec.encode(strokes));

      expect(decoded, hasLength(1));
      // 비유한 좌표(x/y) 점 2개는 버려지고, 필압만 이상한 점은 0.5로 보정.
      expect(decoded.single.points, hasLength(2));
      expect(decoded.single.points[0].pressure, 0.5);
      expect(decoded.single.points[1].x, 7);
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
