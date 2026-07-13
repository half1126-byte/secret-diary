import 'package:flutter_test/flutter_test.dart';
import 'package:secret_diary/data/models/chat_message.dart';
import 'package:secret_diary/data/repositories/diary_repository.dart';
import 'package:secret_diary/services/ai/prompt_builder.dart';

ChatMessage msg(String text, {MessageRole role = MessageRole.user}) =>
    ChatMessage(
      id: 'id-$text',
      entryId: 'e1',
      role: role,
      text: text,
      createdAt: DateTime(2026, 7, 12),
    );

void main() {
  test('기억 블록과 대화가 함께 조립된다', () {
    final prompt = PromptBuilder.build(
      snippets: [
        EntrySnippet(date: DateTime(2026, 7, 10), text: '어제는 힘들었다'),
      ],
      messages: [
        msg('오늘은 괜찮았어'),
        msg('다행이에요.', role: MessageRole.ai),
        msg('고마워'),
      ],
    );

    expect(prompt.systemInstruction, contains('same language'));
    // 기억 블록 user + model 응답 + 대화 3턴.
    expect(prompt.turns, hasLength(5));
    expect(prompt.turns[0].text, contains('2026-07-10'));
    expect(prompt.turns[0].text, contains('어제는 힘들었다'));
    expect(prompt.turns[1].role, 'model');
    expect(prompt.turns.last.text, '고마워');
    expect(prompt.turns[3].role, 'model');
  });

  test('기억이 없으면 대화만 담긴다', () {
    final prompt = PromptBuilder.build(snippets: [], messages: [msg('안녕')]);
    expect(prompt.turns, hasLength(1));
    expect(prompt.turns.single.role, 'user');
  });

  test('긴 대화는 예산에 맞춰 오래된 메시지를 버린다', () {
    final longText = 'a' * 500;
    final messages = [for (var i = 0; i < 40; i++) msg('$i-$longText')];

    final prompt = PromptBuilder.build(snippets: [], messages: messages);

    final totalChars =
        prompt.turns.fold<int>(0, (sum, t) => sum + t.text.length);
    expect(totalChars, lessThanOrEqualTo(PromptBuilder.charBudget + 600));
    // 가장 최근 메시지는 반드시 포함.
    expect(prompt.turns.last.text, messages.last.text);
    // 가장 오래된 메시지는 잘렸다.
    expect(prompt.turns.map((t) => t.text), isNot(contains(messages.first.text)));
  });

  test('예산을 넘는 메시지 하나만 있어도 반드시 포함한다', () {
    final huge = msg('x' * (PromptBuilder.charBudget * 2));

    final prompt = PromptBuilder.build(snippets: [], messages: [huge]);

    expect(prompt.turns, hasLength(1));
    expect(prompt.turns.single.text, huge.text);
  });

  test('기억 블록이 예산의 절반을 넘지 않는다', () {
    final snippets = [
      for (var i = 0; i < 30; i++)
        EntrySnippet(date: DateTime(2026, 7, i + 1), text: 'x' * 200),
    ];

    final prompt = PromptBuilder.build(snippets: snippets, messages: [msg('hi')]);

    final memory = prompt.turns.first.text;
    expect(memory.length, lessThanOrEqualTo(PromptBuilder.charBudget ~/ 2 + 300));
  });
}
