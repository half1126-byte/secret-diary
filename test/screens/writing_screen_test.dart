import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:secret_diary/data/models/diary_entry.dart';
import 'package:secret_diary/data/repositories/diary_repository.dart';
import 'package:secret_diary/features/writing/canvas/handwriting_canvas.dart';
import 'package:secret_diary/features/writing/writing_screen.dart';
import 'package:secret_diary/services/handwriting/fake_recognizer.dart';

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

  testWidgets('키 없는 빌드는 전송 후 안내 카드가 보인다', (tester) async {
    final env = TestEnv(); // 내장 키 없는 빌드
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

    // AI 미준비 안내 카드.
    expect(find.textContaining('AI 일기 친구가'), findsOneWidget);
    await TestEnv.unmount(tester);
  });

  testWidgets('키가 있으면 답장이 캔버스 위에 손글씨로 써진다', (tester) async {
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
    // 잉크 페이드아웃 + 답장 손글씨 리빌 애니메이션 진행.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 9));

    final messages = await repo.getMessages(entry.id);
    expect(messages, hasLength(2));
    expect(messages.last.text, '오늘 하루도 수고 많았어요.');
    // 대화 화면으로 전환되지 않고 캔버스 위에 답장이 그대로 써진다.
    expect(find.text('오늘 하루도 수고 많았어요.'), findsOneWidget);
    expect(find.text('이어 쓰기'), findsNothing); // 스레드 모드 FAB 없음 = 캔버스 모드
    await TestEnv.unmount(tester);
  });

  testWidgets('마침표를 찍으면 자동으로 전송되고 답장이 써진다', (tester) async {
    final env = TestEnv(
      apiKey: 'test-key',
      recognizer: FakeRecognizer(result: '오늘은 비가 왔다.'),
      geminiHttp: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '비 오는 날, 참 좋죠.'},
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

    // 획을 긋고 (전송 버튼을 누르지 않는다!)
    await tester.timedDrag(
      find.byType(HandwritingCanvas),
      const Offset(80, 30),
      const Duration(milliseconds: 100),
    );
    await tester.pump(const Duration(milliseconds: 1300)); // 인식: '...왔다.'
    expect(find.text('오늘은 비가 왔다.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2300)); // 자동 전송 대기
    await tester.pump(const Duration(seconds: 2)); // 페이드 + 응답
    await tester.pump(const Duration(seconds: 9)); // 손글씨 리빌 완료

    final messages = await repo.getMessages(entry.id);
    expect(messages, hasLength(2));
    expect(messages.first.text, '오늘은 비가 왔다.');
    expect(find.text('비 오는 날, 참 좋죠.'), findsOneWidget);
    await TestEnv.unmount(tester);
  });

  testWidgets('두 번 톡톡 치면 기다리지 않고 바로 전송된다', (tester) async {
    final env = TestEnv(); // 키 없는 빌드 — 저장만 확인
    addTearDown(env.dispose);
    final repo = DiaryRepository(env.db);
    final entry = await repo.createEntry(languageTag: 'ko');

    await pumpWriting(tester, env, entryId: entry.id);

    // 획을 긋고 인식이 끝난 뒤,
    await tester.timedDrag(
      find.byType(HandwritingCanvas),
      const Offset(80, 30),
      const Duration(milliseconds: 100),
    );
    await tester.pump(const Duration(milliseconds: 1300));

    // 마침표 없이도 두 번 톡톡 = 바로 전송.
    await tester.tapAt(tester.getCenter(find.byType(HandwritingCanvas)));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(tester.getCenter(find.byType(HandwritingCanvas)));
    await tester.pump(const Duration(milliseconds: 400));

    final messages = await repo.getMessages(entry.id);
    expect(messages, hasLength(1));
    expect(messages.single.text, '가짜 인식 결과');
    await TestEnv.unmount(tester);
  });

  testWidgets('메모 모드는 AI 없이 조용히 저장만 된다', (tester) async {
    final env = TestEnv(apiKey: 'test-key'); // 키가 있어도 메모는 AI를 부르지 않는다
    addTearDown(env.dispose);
    final repo = DiaryRepository(env.db);
    final entry =
        await repo.createEntry(languageTag: 'ko', kind: EntryKind.memo);

    await pumpWriting(tester, env, entryId: entry.id);
    await writeAndSend(tester);
    await tester.pump(const Duration(seconds: 3));

    final messages = await repo.getMessages(entry.id);
    expect(messages, hasLength(1)); // 사용자 메모만, AI 답장 없음
    expect(find.text('메모에 담아뒀어요.'), findsOneWidget);
    await TestEnv.unmount(tester);
  });

  testWidgets('AI 답장 대기 중 화면을 나가도 예외가 없다', (tester) async {
    final env = TestEnv(
      apiKey: 'test-key',
      geminiHttp: MockClient((request) async {
        // 답장이 늦게 도착하는 상황.
        await Future<void>.delayed(const Duration(seconds: 3));
        return http.Response('{}', 500);
      }),
    );
    addTearDown(env.dispose);
    final repo = DiaryRepository(env.db);
    final entry = await repo.createEntry(languageTag: 'ko');

    await pumpWriting(tester, env, entryId: entry.id);
    await writeAndSend(tester);

    // 답장이 오기 전에 화면을 통째로 내려 dispose시킨다.
    await TestEnv.unmount(tester);
    // 늦게 도착한 응답이 disposed notifyListeners를 부르면 여기서 터진다.
    await tester.pump(const Duration(seconds: 4));

    expect(tester.takeException(), isNull);
  });
}
