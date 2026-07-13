import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// 앱을 열면 낡은 가죽 일기장이 펼쳐지며 페이지가 촤라락 넘어가는 인트로.
///
/// 표지·페이지 모두 코드로 그린다. 탭하면 건너뛴다.
class BookIntro extends StatefulWidget {
  const BookIntro({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<BookIntro> createState() => _BookIntroState();
}

class _BookIntroState extends State<BookIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onFinished();
    })
    ..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 구간 [a, b]를 0~1로 정규화.
  double _seg(double t, double a, double b, [Curve curve = Curves.easeInOut]) {
    return curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
  }

  Matrix4 _turn(double openT) => Matrix4.identity()
    ..setEntry(3, 2, 0.0016)
    ..rotateY(-openT * 2.75);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final fade = 1 - _seg(t, 0.86, 1.0, Curves.easeIn);
        final settle = _seg(t, 0.0, 0.14, Curves.easeOutBack);
        final coverOpen = _seg(t, 0.12, 0.42);

        final size = MediaQuery.sizeOf(context);
        final bookW = min(size.width * 0.66, 300.0);
        final bookH = bookW * 4 / 3;

        return IgnorePointer(
          ignoring: t > 0.85,
          child: Opacity(
            opacity: fade,
            child: GestureDetector(
              onTap: () => _controller.animateTo(1,
                  duration: const Duration(milliseconds: 350)),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.2,
                    colors: [Color(0xFF3A2818), Color(0xFF1C120A)],
                  ),
                ),
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: 0.85 + settle * 0.15 + _seg(t, 0.86, 1.0) * 0.25,
                  child: SizedBox(
                    width: bookW,
                    height: bookH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 뒷표지.
                        _cover(bookW, bookH, isFront: false),
                        // 속지 묶음 (오른쪽 단면 결).
                        Positioned.fill(
                          left: 6,
                          top: 5,
                          right: 3,
                          bottom: 5,
                          child: CustomPaint(painter: _PagesEdgePainter()),
                        ),
                        // 촤라락 넘어가는 낱장들.
                        for (var i = 4; i >= 0; i--)
                          _flippingPage(
                            bookW,
                            bookH,
                            tone: i.isEven
                                ? Palette.cream
                                : const Color(0xFFEFE1BC),
                            openT: _seg(
                                t, 0.34 + i * 0.09, 0.52 + i * 0.09),
                          ),
                        // 앞표지.
                        Transform(
                          alignment: Alignment.centerLeft,
                          transform: _turn(coverOpen),
                          child: _cover(bookW, bookH, isFront: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _flippingPage(double w, double h,
      {required Color tone, required double openT}) {
    if (openT == 0) return const SizedBox.shrink();
    return Positioned(
      left: 6,
      top: 7,
      child: Transform(
        alignment: Alignment.centerLeft,
        transform: _turn(openT),
        child: Container(
          width: w - 12,
          height: h - 14,
          decoration: BoxDecoration(
            color: tone,
            borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(6)),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cover(double w, double h, {required bool isFront}) {
    return SizedBox(
      width: w,
      height: h,
      child: CustomPaint(painter: _LeatherCoverPainter(isFront: isFront)),
    );
  }
}

/// 속지 묶음의 오른쪽/아래 단면 결.
class _PagesEdgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = const Color(0xFFE8D8B0),
    );
    final line = Paint()
      ..color = const Color(0x338A6F45)
      ..strokeWidth = 1;
    for (var x = size.width - 2.0; x > size.width - 12; x -= 2.4) {
      canvas.drawLine(Offset(x, 4), Offset(x, size.height - 4), line);
    }
  }

  @override
  bool shouldRepaint(_PagesEdgePainter oldDelegate) => false;
}

/// 낡은 가죽 표지 — 스크래치, 테두리 장식, 가죽끈과 버클.
class _LeatherCoverPainter extends CustomPainter {
  _LeatherCoverPainter({required this.isFront});

  final bool isFront;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndCorners(
      rect,
      topRight: const Radius.circular(10),
      bottomRight: const Radius.circular(10),
      topLeft: const Radius.circular(3),
      bottomLeft: const Radius.circular(3),
    );
    canvas.drawShadow(Path()..addRRect(rrect), Colors.black, 8, false);
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF6B4423));
    // 세월 얼룩과 스크래치.
    final random = Random(7);
    final wear = Paint()..color = const Color(0x22D9B36B);
    for (var i = 0; i < 26; i++) {
      canvas.drawCircle(
        Offset(random.nextDouble() * size.width,
            random.nextDouble() * size.height),
        random.nextDouble() * 14 + 2,
        wear,
      );
    }
    final scratch = Paint()
      ..color = const Color(0x33D9B36B)
      ..strokeWidth = 0.9;
    for (var i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final len = random.nextDouble() * 30 + 8;
      final a = random.nextDouble() * pi;
      canvas.drawLine(
          Offset(x, y), Offset(x + cos(a) * len, y + sin(a) * len), scratch);
    }
    // 모서리 장식 아치 (사진 속 엠보싱 느낌).
    final emboss = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x40311B0C);
    canvas.drawCircle(Offset(0, size.height * 0.18), size.width * 0.3, emboss);
    canvas.drawCircle(
        Offset(size.width, size.height * 0.85), size.width * 0.34, emboss);

    if (isFront) {
      // 가죽끈.
      final strap = Rect.fromLTWH(
          0, size.height * 0.42, size.width, size.height * 0.09);
      canvas.drawRect(strap, Paint()..color = const Color(0xFF5A3418));
      canvas.drawRect(
        strap,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0x66301A0A),
      );
      // 버클.
      final buckle = Rect.fromCenter(
        center: Offset(size.width * 0.56, size.height * 0.465),
        width: size.width * 0.13,
        height: size.height * 0.07,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(buckle, const Radius.circular(3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFF9A8156),
      );
      // 스파인 쪽 어두운 접힘.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, 10, size.height),
        Paint()..color = const Color(0x40200F05),
      );
    }
  }

  @override
  bool shouldRepaint(_LeatherCoverPainter oldDelegate) =>
      oldDelegate.isFront != isFront;
}
