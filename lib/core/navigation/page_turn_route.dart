import 'dart:math';

import 'package:flutter/material.dart';

/// 책장을 넘기듯 새 화면이 왼쪽 모서리를 축으로 펼쳐지는 라우트.
class PageTurnRoute<T> extends PageRouteBuilder<T> {
  PageTurnRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: const Duration(milliseconds: 480),
          reverseTransitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final turn = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return AnimatedBuilder(
              animation: turn,
              child: child,
              builder: (context, page) {
                final angle = (1 - turn.value) * -pi / 2.2;
                return Transform(
                  alignment: Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(angle),
                  child: page,
                );
              },
            );
          },
        );
}
