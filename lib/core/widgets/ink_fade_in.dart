import 'package:flutter/material.dart';

/// 잉크가 종이에 스며들 듯 아래에서 살짝 떠오르며 나타나는 진입 애니메이션.
class InkFadeIn extends StatefulWidget {
  const InkFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 600),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<InkFadeIn> createState() => _InkFadeInState();
}

class _InkFadeInState extends State<InkFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<Offset> _offset = Tween(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
