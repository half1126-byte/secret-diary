/// 답장 연출·전송 감각에 대한 사용자 취향.
class WritingPrefs {
  const WritingPrefs({
    this.replyFont = 'auto',
    this.replyScale = 1.0,
    this.revealMsPerChar = 60,
    this.autoSendMs = 2200,
  });

  /// 답장 손글씨 폰트. 'auto'면 작성 언어에 맞는 폰트.
  final String replyFont;

  /// 답장 글씨 크기 배율 (0.8 ~ 1.6).
  final double replyScale;

  /// 답장이 써지는 속도 — 글자당 밀리초 (낮을수록 빠름).
  final int revealMsPerChar;

  /// 마침표를 찍은 뒤 자동 전송까지의 대기 밀리초.
  final int autoSendMs;

  WritingPrefs copyWith({
    String? replyFont,
    double? replyScale,
    int? revealMsPerChar,
    int? autoSendMs,
  }) =>
      WritingPrefs(
        replyFont: replyFont ?? this.replyFont,
        replyScale: replyScale ?? this.replyScale,
        revealMsPerChar: revealMsPerChar ?? this.revealMsPerChar,
        autoSendMs: autoSendMs ?? this.autoSendMs,
      );
}
