import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

class SecretDiaryApp extends StatelessWidget {
  const SecretDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '비밀 일기',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeScreen(),
    );
  }
}
