import 'package:flutter/material.dart';

import '../../core/widgets/paper_background.dart';

/// 홈 타임라인 — 데이터 계층 연결 전 임시 화면.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaperBackground(
        child: Center(
          child: Text('비밀 일기', style: Theme.of(context).textTheme.headlineMedium),
        ),
      ),
    );
  }
}
