import 'dart:ui';

import '../../data/models/stroke.dart';

/// 손글씨 인식 결과.
class RecognitionResult {
  const RecognitionResult({required this.text, this.candidates = const []});

  final String text;

  /// 차선 후보들 (필요 시 UI에서 선택지로 제공 가능).
  final List<String> candidates;
}

/// 손글씨 인식기 추상화.
///
/// 실제 구현(ML Kit)은 실기기에서만 동작하므로, 테스트와
/// 데스크톱 실행에서는 가짜 구현으로 대체한다.
abstract class HandwritingRecognizer {
  /// 획들을 [languageTag] 언어로 인식한다.
  ///
  /// [preContext]는 이미 인식된 직전 텍스트 (정확도 향상용, 최대 20자).
  /// [writingArea]는 캔버스 크기.
  Future<RecognitionResult> recognize(
    List<DiaryStroke> strokes, {
    required String languageTag,
    String preContext = '',
    Size? writingArea,
  });

  /// 언어 모델이 기기에 있는지 확인.
  Future<bool> isModelDownloaded(String languageTag);

  /// 언어 모델 다운로드 (~20MB).
  Future<void> downloadModel(String languageTag);

  Future<void> deleteModel(String languageTag);

  /// 기기에 내려받은 언어 모델 태그 목록.
  Future<List<String>> downloadedModels();

  void dispose() {}
}
