import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_diary/coach/coach_app.dart';
import 'package:secret_diary/coach/coach_prompt.dart';
import 'package:secret_diary/coach/coach_screen.dart';
import 'package:secret_diary/data/models/chat_message.dart';

import '../helpers/test_env.dart';

ChatMessage msg(String text, {MessageRole role = MessageRole.user}) =>
    ChatMessage(
      id: 'id-$text',
      entryId: 'e1',
      role: role,
      text: text,
      createdAt: DateTime(2026, 7, 13),
    );

void main() {
  group('CoachPrompt', () {
    test('팩폭 플로우와 안전 규칙이 시스템 프롬프트에 있다', () {
      final prompt = CoachPrompt.build([msg('퇴사하고 싶다')]);
      expect(prompt.systemInstruction, contains('DIAGNOSE'));
      expect(prompt.systemInstruction, contains('FORCE A CHOICE'));
      expect(prompt.systemInstruction, contains('핑계'));
      expect(prompt.systemInstruction, contains('same language'));
      expect(prompt.systemInstruction, contains('self-harm'));
      expect(prompt.turns.single.text, '퇴사하고 싶다');
    });

    test('예산을 넘으면 오래된 메시지를 버리되 최근 것은 지킨다', () {
      final messages = [for (var i = 0; i < 40; i++) msg('$i-${'x' * 500}')];
      final prompt = CoachPrompt.build(messages);
      expect(prompt.turns.last.text, messages.last.text);
      expect(prompt.turns.length, lessThan(40));
    });
  });

  group('CoachScreen', () {
    testWidgets('메시지를 보내면 팩폭 답장이 온다', (tester) async {
      final env = TestEnv(
        apiKey: 'test-key',
        geminiHttp: MockClient((_) async => http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': '하. 상태 안 좋다.\n지금 해.'},
                      ],
                    },
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            )),
      );
      addTearDown(env.dispose);

      await tester.pumpWidget(ProviderScope(
        overrides: env.overrides,
        child: const CoachApp(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('뭐부터 털어놓을 건데?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '퇴사하고 싶은데 무섭다');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('퇴사하고 싶은데 무섭다'), findsOneWidget);
      expect(find.text('하. 상태 안 좋다.\n지금 해.'), findsOneWidget);
      await TestEnv.unmount(tester);
    });

    testWidgets('키 없는 빌드는 오류 버블과 다시 버튼', (tester) async {
      final env = TestEnv();
      addTearDown(env.dispose);

      await tester.pumpWidget(ProviderScope(
        overrides: env.overrides,
        child: const CoachApp(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(find.byType(TextField), '도와줘');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('AI가 없다'), findsOneWidget);
      expect(find.text('다시'), findsOneWidget);
      await TestEnv.unmount(tester);
    });

    testWidgets('화면이 CoachScreen을 띄운다', (tester) async {
      final env = TestEnv();
      addTearDown(env.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: env.overrides,
        child: const CoachApp(),
      ));
      await tester.pump();
      expect(find.byType(CoachScreen), findsOneWidget);
      expect(find.text('팩폭상담소'), findsOneWidget);
      await TestEnv.unmount(tester);
    });
  });
}
