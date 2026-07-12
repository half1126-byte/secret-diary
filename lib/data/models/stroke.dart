import 'dart:convert';
import 'dart:ui';

/// 손글씨 획의 한 점. 화면 렌더링과 ML Kit 인식 양쪽에 쓰이는 단일 원본.
class DiaryPoint {
  const DiaryPoint({
    required this.x,
    required this.y,
    required this.pressure,
    required this.t,
  });

  final double x;
  final double y;

  /// 0~1로 정규화된 필압. 손가락 입력은 0.5 고정.
  final double pressure;

  /// 일기 항목 시작 시점 기준 경과 밀리초 (ML Kit 인식 정확도에 사용).
  final int t;

  Offset get offset => Offset(x, y);
}

/// 펜을 댔다 뗄 때까지의 획 하나.
class DiaryStroke {
  const DiaryStroke({required this.points});

  final List<DiaryPoint> points;

  bool get isEmpty => points.isEmpty;
}

/// 획 목록 ↔ 압축 JSON 직렬화.
///
/// 형식: `{"s":[[[x,y,p,t],...], ...]}` — 좌표는 소수 1자리로 반올림해
/// 빽빽한 한 페이지도 ~100KB 이하로 유지한다.
abstract final class StrokeCodec {
  static String encode(List<DiaryStroke> strokes) {
    double round1(double v) => (v * 10).roundToDouble() / 10;
    final s = [
      for (final stroke in strokes)
        [
          for (final p in stroke.points)
            [round1(p.x), round1(p.y), round1(p.pressure), p.t],
        ],
    ];
    return jsonEncode({'s': s});
  }

  static List<DiaryStroke> decode(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final s = map['s'] as List<dynamic>;
    return [
      for (final stroke in s)
        DiaryStroke(points: [
          for (final p in stroke as List<dynamic>)
            DiaryPoint(
              x: ((p as List<dynamic>)[0] as num).toDouble(),
              y: (p[1] as num).toDouble(),
              pressure: (p[2] as num).toDouble(),
              t: (p[3] as num).toInt(),
            ),
        ]),
    ];
  }

  /// 획 전체를 감싸는 사각형. 썸네일 렌더링에 사용.
  static Rect boundingBox(List<DiaryStroke> strokes) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final stroke in strokes) {
      for (final p in stroke.points) {
        if (p.x < minX) minX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.x > maxX) maxX = p.x;
        if (p.y > maxY) maxY = p.y;
      }
    }
    if (minX == double.infinity) return Rect.zero;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
