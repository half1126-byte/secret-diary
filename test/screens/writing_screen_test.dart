import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:secret_diary/data/repositories/diary_repository.dart';
import 'package:secret_diary/features/writing/canvas/handwriting_canvas.dart';
import 'package:secret_diary/features/writing/writing_screen.dart';

import '../helpers/test_env.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  Future<void> pumpWriting(WidgetTester tester, TestEnv env,
      {required String entryId}) async {
    final repo = DiaryRepository(env.db);
    final entry = (await repo.getEntry(entryId))!;
    await tester.pumpWidget(ProviderScope(
      overrides: env.overrides,
      child: MaterialApp(home: WritingScreen(entry: entry)),
    ));
    await tester.pump();
  }

  Future<void> writeAndSend(WidgetTester tester) async {
    // 획 긋기.
    await tester.timedDrag(
      find.byType(HandwritingCanvas),
      const Offset(80, 30),
      const Duration(milliseconds: 100),
    );
    // 디바운스 후 인식.
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('가짜 인식 결과'), findsOneWidget);
    // 전송.
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('키가 없으면 전송 후 키 연결 카드가 보인다', (tester) async {
    final env = TestEnv(); // apiKey 없음
    addTearDown(env.dispose);
    final repo = DiaryRepository(env.db);
    final entry = await repo.createEntry(languageTag: 'ko');

    await pumpWriting(tester, env, entryId: entry.id);
    await writeAndSend(tester);
    await tester.pump(const Duration(milliseconds: 700));

    // 사용자 메시지는 저장됐다.
    final messages = await repo.getMessages(entry.id);
    expect(messages, hasLength(1));
    expect(messages.single.text, '가짜 인식 결과');
    expect(messages.single.strokes, isNotEmpty);

    // 키 연결 안내 카드.
    expect(find.textContaining('무료 Gemini 키를 연결하면'), findsOneWidget);
    await TestEnv.unmount(tester);
  });

  testWidgets('키가 있으면 AI 답장이 스레드에 나타난다', (tester) async {
    final env = TestEnv(
      apiKey: 'test-key',
      geminiHttp: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '오늘 하루도 수고 많았어요.'},
                  ],
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(env.dispose);
    final repo = DiaryRepository(env.db);
    final entry = await repo.createEntry(languageTag: 'ko');

    await pumpWriting(tester, env, entryId: entry.id);
    await writeAndSend(tester);
    await tester.pump(const Duration(seconds: 1));

    final messages = await repo.getMessages(entry.id);
    expect(messages, hasLength(2));
    expect(messages.last.text, '오늘 하루도 수고 많았어요.');
    expect(find.text('오늘 하루도 수고 많았어요.'), findsOneWidget);
    await TestEnv.unmount(tester);
  });
}
