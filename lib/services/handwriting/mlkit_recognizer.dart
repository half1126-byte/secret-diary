import 'dart:ui';

import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as mlkit;

import '../../core/theme/script_fonts.dart';
import '../../data/models/stroke.dart';
import 'recognizer.dart';

/// Google ML Kit Digital Ink 기반 온디바이스 손글씨 인식기.
///
/// 완전 무료이며, 획 데이터가 기기를 벗어나지 않는다.
/// 실기기(Android/iOS)에서만 동작한다.
class MlKitRecognizer implements HandwritingRecognizer {
  final _modelManager = mlkit.DigitalInkRecognizerModelManager();

  mlkit.DigitalInkRecognizer? _recognizer;
  String? _recognizerLanguage;

  /// 인식 호출을 직렬화하는 큐.
  ///
  /// 언어 전환 시 이전 인식기를 close()하는데, 진행 중인 recognize가
  /// 그 인스턴스를 쓰고 있으면 use-after-close 크래시가 난다.
  /// 큐로 순서를 보장해 close가 항상 사용이 끝난 뒤에 일어나게 한다.
  Future<void> _queue = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  mlkit.DigitalInkRecognizer _recognizerFor(String languageTag) {
    if (_recognizer == null || _recognizerLanguage != languageTag) {
      _recognizer?.close();
      _recognizer = mlkit.DigitalInkRecognizer(languageCode: languageTag);
      _recognizerLanguage = languageTag;
    }
    return _recognizer!;
  }

  @override
  Future<RecognitionResult> recognize(
    List<DiaryStroke> strokes, {
    required String languageTag,
    String preContext = '',
    Size? writingArea,
  }) {
    if (strokes.isEmpty) {
      return Future.value(const RecognitionResult(text: ''));
    }
    return _serialized(() => _recognize(
          strokes,
          languageTag: languageTag,
          preContext: preContext,
          writingArea: writingArea,
        ));
  }

  Future<RecognitionResult> _recognize(
    List<DiaryStroke> strokes, {
    required String languageTag,
    String preContext = '',
    Size? writingArea,
  }) async {

    final ink = mlkit.Ink()
      ..strokes = [
        for (final stroke in strokes)
          mlkit.Stroke()
            ..points = [
              for (final p in stroke.points)
                mlkit.StrokePoint(x: p.x, y: p.y, t: p.t),
            ],
      ];

    final context = mlkit.DigitalInkRecognitionContext(
      preContext: preContext.isEmpty ? null : preContext,
      writingArea: writingArea == null
          ? null
          : mlkit.WritingArea(
              width: writingArea.width,
              height: writingArea.height,
            ),
    );

    final candidates =
        await _recognizerFor(languageTag).recognize(ink, context: context);

    if (candidates.isEmpty) return const RecognitionResult(text: '');
    return RecognitionResult(
      text: candidates.first.text,
      candidates: [for (final c in candidates.skip(1).take(3)) c.text],
    );
  }

  @override
  Future<bool> isModelDownloaded(String languageTag) =>
      _modelManager.isModelDownloaded(languageTag);

  @override
  Future<void> downloadModel(String languageTag) =>
      _modelManager.downloadModel(languageTag, isWifiRequired: false);

  @override
  Future<void> deleteModel(String languageTag) =>
      _modelManager.deleteModel(languageTag);

  @override
  Future<List<String>> downloadedModels() async {
    // ML Kit에는 목록 API가 없어 지원 언어를 하나씩 조회한다.
    final result = <String>[];
    for (final tag in ScriptFonts.supportedLanguages.keys) {
      if (await _modelManager.isModelDownloaded(tag)) result.add(tag);
    }
    return result;
  }

  @override
  void dispose() {
    // 진행 중인 인식이 끝난 뒤에 닫는다.
    _serialized(() async {
      await _recognizer?.close();
      _recognizer = null;
      _recognizerLanguage = null;
    });
  }
}
