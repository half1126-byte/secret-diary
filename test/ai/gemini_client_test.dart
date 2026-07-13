import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_diary/services/ai/gemini_client.dart';
import 'package:secret_diary/services/ai/prompt_builder.dart';

const _prompt = BuiltPrompt(
  systemInstruction: 'be kind',
  turns: [PromptTurn(role: 'user', text: '안녕')],
);

String _okBody(String text) => jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text},
            ],
          },
        },
      ],
    });

void main() {
  test('정상 응답에서 텍스트를 추출한다', () async {
    late http.Request captured;
    final client = GeminiClient(
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(_okBody('반가워요!'), 200,
            headers: {'content-type': 'application/json'});
      }),
    );

    final reply = await client.generateReply(
      apiKey: 'test-key',
      model: 'gemini-2.5-flash',
      prompt: _prompt,
    );

    expect(reply, '반가워요!');
    expect(captured.url.path, contains('gemini-2.5-flash:generateContent'));
    expect(captured.headers['x-goog-api-key'], 'test-key');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['systemInstruction'], isNotNull);
    expect((body['contents'] as List).single['role'], 'user');
  });

  test('키가 없으면 noApiKey 예외', () async {
    final client = GeminiClient(httpClient: MockClient((_) async {
      fail('호출되면 안 됨');
    }));

    expect(
      () => client.generateReply(apiKey: '  ', model: 'm', prompt: _prompt),
      throwsA(isA<GeminiException>()
          .having((e) => e.type, 'type', GeminiErrorType.noApiKey)),
    );
  });

  test('429는 한 번 재시도 후 성공한다', () async {
    var calls = 0;
    final client = GeminiClient(
      httpClient: MockClient((_) async {
        calls++;
        if (calls == 1) {
          return http.Response('{}', 429, headers: {'retry-after': '0'});
        }
        return http.Response(_okBody('두 번째에 성공'), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );

    final reply = await client.generateReply(
        apiKey: 'k', model: 'm', prompt: _prompt);
    expect(reply, '두 번째에 성공');
    expect(calls, 2);
  });

  test('계속 429면 rateLimited 예외', () async {
    final client = GeminiClient(
      httpClient: MockClient(
        (_) async => http.Response('{}', 429, headers: {'retry-after': '0'}),
      ),
    );

    expect(
      () => client.generateReply(apiKey: 'k', model: 'm', prompt: _prompt),
      throwsA(isA<GeminiException>()
          .having((e) => e.type, 'type', GeminiErrorType.rateLimited)),
    );
  });

  test('403은 invalidApiKey 예외', () async {
    final client = GeminiClient(
      httpClient: MockClient(
        (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'API key not valid'},
            }),
            403),
      ),
    );

    expect(
      () => client.generateReply(apiKey: 'bad', model: 'm', prompt: _prompt),
      throwsA(isA<GeminiException>()
          .having((e) => e.type, 'type', GeminiErrorType.invalidApiKey)
          .having((e) => e.message, 'message', contains('API key'))),
    );
  });

  test('404(모델 없음)는 키 오류가 아니라 other', () async {
    final client = GeminiClient(
      httpClient: MockClient(
        (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'model not found', 'status': 'NOT_FOUND'},
            }),
            404),
      ),
    );

    expect(
      () => client.generateReply(apiKey: 'k', model: 'no-model', prompt: _prompt),
      throwsA(isA<GeminiException>()
          .having((e) => e.type, 'type', GeminiErrorType.other)
          .having((e) => e.message, 'message', contains('no-model'))),
    );
  });

  test('일반 400(요청 오류)은 키 오류가 아니라 other', () async {
    final client = GeminiClient(
      httpClient: MockClient(
        (_) async => http.Response(
            jsonEncode({
              'error': {
                'message': 'Invalid JSON payload',
                'status': 'INVALID_ARGUMENT',
              },
            }),
            400),
      ),
    );

    expect(
      () => client.generateReply(apiKey: 'k', model: 'm', prompt: _prompt),
      throwsA(isA<GeminiException>()
          .having((e) => e.type, 'type', GeminiErrorType.other)),
    );
  });

  test('400이라도 API_KEY_INVALID면 invalidApiKey', () async {
    final client = GeminiClient(
      httpClient: MockClient(
        (_) async => http.Response(
            jsonEncode({
              'error': {
                'message': 'API key not valid. Please pass a valid API key.',
                'status': 'INVALID_ARGUMENT',
                'details': [
                  {'reason': 'API_KEY_INVALID'},
                ],
              },
            }),
            400),
      ),
    );

    expect(
      () => client.generateReply(apiKey: 'bad', model: 'm', prompt: _prompt),
      throwsA(isA<GeminiException>()
          .having((e) => e.type, 'type', GeminiErrorType.invalidApiKey)),
    );
  });

  test('깨진 JSON이면 other 예외', () async {
    final client = GeminiClient(
      httpClient: MockClient((_) async => http.Response('not json', 200)),
    );

    expect(
      () => client.generateReply(apiKey: 'k', model: 'm', prompt: _prompt),
      throwsA(isA<GeminiException>()
          .having((e) => e.type, 'type', GeminiErrorType.other)),
    );
  });
}
