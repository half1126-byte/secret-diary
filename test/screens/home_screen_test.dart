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

    expect(find.textContaining('답장할게요'), findsOneWidget);
    expect(find.text('오늘의 페이지 열기'), findsOneWidget);
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

  testWidgets('인식기가 고장나도 오늘의 페이지 열기가 열린다', (tester) async {
    final env = TestEnv(recognizer: ThrowingRecognizer());
    addTearDown(env.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: env.overrides,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pump();

    await tester.tap(find.text('오늘의 페이지 열기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 다운로드 실패 시트가 뜨면 '나중에'로 넘어간다.
    expect(find.text('모델을 내려받지 못했어요'), findsOneWidget);
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();

    // 모델이 없어도 쓰기 화면으로 진입해야 한다.
    expect(
        find.text('마침표(.)를 찍거나 두 번 톡톡 치면 답장이 와요'), findsOneWidget);
    await TestEnv.unmount(tester);
  });
}
