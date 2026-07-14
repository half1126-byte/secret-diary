import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/models/stroke.dart';
import '../../features/writing/canvas/stroke_painter.dart';

/// 손그림(획들)을 AI에게 보여줄 PNG(base64)로 렌더링한다.
///
/// 아이디어 스케치 해석용 — 흰 배경 위 검정 잉크로 그려
/// 모델이 알아보기 좋게 만든다.
Future<String> strokesToPngBase64(
  List<DiaryStroke> strokes, {
  double maxDimension = 768,
}) async {
  final box = StrokeCodec.boundingBox(strokes).inflate(24);
  final w = box.width <= 0 ? 1.0 : box.width;
  final h = box.height <= 0 ? 1.0 : box.height;
  final scale = maxDimension / (w > h ? w : h);
  final outW = (w * scale).clamp(64.0, maxDimension);
  final outH = (h * scale).clamp(64.0, maxDimension);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, outW, outH),
    Paint()..color = Colors.white,
  );
  canvas.scale(scale);
  canvas.translate(-box.left, -box.top);
  StrokesPainter(strokes: strokes, color: Colors.black, strokeSize: 5)
      .paint(canvas, Size(w, h));

  final image =
      await recorder.endRecording().toImage(outW.round(), outH.round());
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return base64Encode(bytes!.buffer.asUint8List());
  } finally {
    image.dispose();
  }
}
