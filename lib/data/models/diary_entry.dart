/// 일기 항목 하나 (하루치 또는 한 세션의 대화 묶음).
class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.languageTag,
    this.title,
    this.mood,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 작성 언어 (BCP-47, 예: 'ko').
  final String languageTag;

  /// 첫 인식 텍스트의 앞부분 (~30자). 타임라인 카드에 표시.
  final String? title;

  final String? mood;
}
