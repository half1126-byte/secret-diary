import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:secret_diary/data/models/chat_message.dart';
import 'package:secret_diary/data/repositories/diary_repository.dart';
import 'package:secret_diary/features/home/home_screen.dart';

import '../helpers/test_env.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  testWidgets('빈 상태 안내가 보인다', (tester) async {
    final env = TestEnv();
    addTearDown(env.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: env.overrides,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pump();

    expect(find.textContaining('손으로 적어보세요'), findsOneWidget);
    expect(find.text('오늘 일기 쓰기'), findsOneWidget);
    await TestEnv.unmount(tester);
  });

  testWidgets('저장된 일기가 타임라인에 나온다', (tester) async {
    final env = TestEnv();
    addTearDown(env.dispose);

    final repo = DiaryRepository(env.db);
    final entry = await repo.createEntry(languageTag: 'ko');
    await repo.appendMessage(
      entryId: entry.id,
      role: MessageRole.user,
      text: '바람이 좋았던 하루',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: env.overrides,
      child: const MaterialApp(home: HomeScreen()),
    ));
    // 스트림 반영 + 진입 애니메이션.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('바람이 좋았던 하루'), findsOneWidget);
    await TestEnv.unmount(tester);
  });
}
