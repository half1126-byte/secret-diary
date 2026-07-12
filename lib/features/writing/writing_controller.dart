import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../data/models/stroke.dart';
import '../../services/handwriting/recognizer.dart';

/// 쓰기 화면의 잉크 상태를 관리하는 컨트롤러.
///
/// - 아직 전송하지 않은 획 목록과 인식 텍스트를 들고 있다.
/// - 획이 멈춘 뒤 [recognizeDebounce]가 지나면 자동으로 인식을 돌린다.
/// - 인식 결과는 세대(generation) 검사로 낡은 결과를 버린다.
class WritingController extends ChangeNotifier {
  WritingController({
    required HandwritingRecognizer recognizer,
    required String languageTag,
    this.recognizeDebounce = const Duration(milliseconds: 1200),
    this.preContextProvider,
  })  : _recognizer = recognizer, // ignore: prefer_initializing_formals
        _languageTag = languageTag; // ignore: prefer_initializing_formals

  final HandwritingRecognizer _recognizer;
  final Duration recognizeDebounce;

  /// 이미 전송된 텍스트의 끝부분을 인식 힌트로 제공.
  final String Function()? preContextProvider;

  String _languageTag;
  String get languageTag => _languageTag;
  set languageTag(String tag) {
    if (tag == _languageTag) return;
    _languageTag = tag;
    _scheduleRecognition(immediate: true);
    notifyListeners();
  }

  final List<DiaryStroke> _strokes = [];
  List<DiaryStroke> get strokes => List.unmodifiable(_strokes);
  bool get hasInk => _strokes.isNotEmpty;

  String _recognizedText = '';
  String get recognizedText => _recognizedText;
  bool _textEditedManually = false;

  bool _recognizing = false;
  bool get recognizing => _recognizing;

  Size? writingArea;

  Timer? _debounce;
  int _generation = 0;

  void addStroke(DiaryStroke stroke) {
    _strokes.add(stroke);
    _textEditedManually = false;
    _scheduleRecognition();
    notifyListeners();
  }

  void undoStroke() {
    if (_strokes.isEmpty) return;
    _strokes.removeLast();
    _textEditedManually = false;
    if (_strokes.isEmpty) {
      _debounce?.cancel();
      _generation++;
      _recognizedText = '';
      _recognizing = false;
    } else {
      _scheduleRecognition();
    }
    notifyListeners();
  }

  void clear() {
    _debounce?.cancel();
    _generation++;
    _strokes.clear();
    _recognizedText = '';
    _recognizing = false;
    _textEditedManually = false;
    notifyListeners();
  }

  /// 사용자가 인식 텍스트를 직접 고쳤을 때.
  void editRecognizedText(String text) {
    _recognizedText = text;
    _textEditedManually = true;
    _debounce?.cancel();
    _generation++;
    _recognizing = false;
    notifyListeners();
  }

  /// 전송 시점: 현재 획과 텍스트를 스냅샷으로 떼어내고 캔버스를 비운다.
  ({List<DiaryStroke> strokes, String text})? takeSnapshot() {
    final text = _recognizedText.trim();
    if (_strokes.isEmpty && text.isEmpty) return null;
    final snapshot = (strokes: List<DiaryStroke>.of(_strokes), text: text);
    clear();
    return snapshot;
  }

  void _scheduleRecognition({bool immediate = false}) {
    _debounce?.cancel();
    if (_strokes.isEmpty) return;
    if (immediate) {
      _runRecognition();
    } else {
      _debounce = Timer(recognizeDebounce, _runRecognition);
    }
  }

  Future<void> _runRecognition() async {
    final generation = ++_generation;
    _recognizing = true;
    notifyListeners();
    try {
      final result = await _recognizer.recognize(
        List.of(_strokes),
        languageTag: _languageTag,
        preContext: _preContext(),
        writingArea: writingArea,
      );
      if (generation != _generation || _textEditedManually) return;
      _recognizedText = result.text;
    } catch (_) {
      // 인식 실패는 치명적이지 않다 — 기존 텍스트 유지.
      if (generation != _generation) return;
    } finally {
      if (generation == _generation) {
        _recognizing = false;
        notifyListeners();
      }
    }
  }

  String _preContext() {
    final context = preContextProvider?.call() ?? '';
    return context.length > 20
        ? context.substring(context.length - 20)
        : context;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
