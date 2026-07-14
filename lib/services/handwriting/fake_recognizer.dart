import 'dart:ui';

import '../../data/models/stroke.dart';
import 'recognizer.dart';

/// 테스트·개발용 가짜 인식기.
class FakeRecognizer implements HandwritingRecognizer {
  FakeRecognizer({this.result = '가짜 인식 결과', this.delay = Duration.zero});

  final String result;
  final Duration delay;

  final Set<String> _downloaded = {};
  int recognizeCalls = 0;
  List<DiaryStroke>? lastStrokes;
  String? lastLanguageTag;

  @override
  Future<RecognitionResult> recognize(
    List<DiaryStroke> strokes, {
    required String languageTag,
    String preContext = '',
    Size? writingArea,
  }) async {
    recognizeCalls++;
    lastStrokes = strokes;
    lastLanguageTag = languageTag;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return RecognitionResult(text: strokes.isEmpty ? '' : result);
  }

  @override
  Future<bool> isModelDownloaded(String languageTag) async =>
      _downloaded.contains(languageTag);

  @override
  Future<void> downloadModel(String languageTag) async {
    _downloaded.add(languageTag);
  }

  @override
  Future<void> deleteModel(String languageTag) async {
    _downloaded.remove(languageTag);
  }

  @override
  Future<List<String>> downloadedModels() async => _downloaded.toList();

  @override
  void dispose() {}
}
