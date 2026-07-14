import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/book_intro.dart';
import 'features/home/home_screen.dart';

class SecretDiaryApp extends StatelessWidget {
  const SecretDiaryApp({super.key, this.showIntro = true});

  /// 시작 시 가죽 일기장 펼침 인트로를 보여줄지.
  final bool showIntro;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Re:Me',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: _Root(showIntro: showIntro),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root({required this.showIntro});

  final bool showIntro;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late bool _intro = widget.showIntro;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const HomeScreen(),
        if (_intro)
          BookIntro(onFinished: () => setState(() => _intro = false)),
      ],
    );
  }
}
