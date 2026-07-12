import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'prompt_builder.dart';

/// Gemini 호출 실패 유형.
enum GeminiErrorType { noApiKey, invalidApiKey, rateLimited, network, other }

class GeminiException implements Exception {
  const GeminiException(this.type, [this.message = '']);

  final GeminiErrorType type;
  final String message;

  @override
  String toString() => 'GeminiException($type, $message)';
}

/// Google Gemini generateContent REST 클라이언트.
///
/// 무료 등급으로 충분히 동작하며, 공식 Dart 패키지 대신 얇은 REST 호출을
/// 사용해 의존성·지원 종료 리스크를 피한다.
class GeminiClient {
  GeminiClient({http.Client? httpClient, this.maxRetries = 1})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// 429/503에 대한 재시도 횟수.
  final int maxRetries;

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  /// 대화를 보내고 답장 텍스트를 받는다.
  Future<String> generateReply({
    required String apiKey,
    required String model,
    required BuiltPrompt prompt,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const GeminiException(GeminiErrorType.noApiKey);
    }

    final uri = Uri.parse('$_base/models/$model:generateContent');
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': prompt.systemInstruction},
        ],
      },
      'contents': [
        for (final turn in prompt.turns)
          {
            'role': turn.role,
            'parts': [
              {'text': turn.text},
            ],
          },
      ],
      'generationConfig': {
        'temperature': 0.9,
        'maxOutputTokens': 1024,
      },
    });

    for (var attempt = 0; ; attempt++) {
      http.Response response;
      try {
        response = await _http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: body,
        );
      } on Exception catch (e) {
        throw GeminiException(GeminiErrorType.network, e.toString());
      }

      switch (response.statusCode) {
        case 200:
          // 서버 charset 헤더와 무관하게 UTF-8로 해석한다.
          return _extractText(utf8.decode(response.bodyBytes));
        case 400:
        case 401:
        case 403:
          throw GeminiException(
              GeminiErrorType.invalidApiKey, _errorMessage(response.body));
        case 429:
        case 503:
          if (attempt < maxRetries) {
            await Future<void>.delayed(_retryDelay(response));
            continue;
          }
          throw GeminiException(
              GeminiErrorType.rateLimited, _errorMessage(response.body));
        default:
          throw GeminiException(
            GeminiErrorType.other,
            'HTTP ${response.statusCode}: ${_errorMessage(response.body)}',
          );
      }
    }
  }

  /// 설정 화면의 "연결 테스트"용 가벼운 호출.
  Future<bool> testConnection({
    required String apiKey,
    required String model,
  }) async {
    try {
      await generateReply(
        apiKey: apiKey,
        model: model,
        prompt: const BuiltPrompt(
          systemInstruction: 'Reply with a single short word.',
          turns: [PromptTurn(role: 'user', text: 'hello')],
        ),
      );
      return true;
    } on GeminiException {
      rethrow;
    }
  }

  static Duration _retryDelay(http.Response response) {
    final header = response.headers['retry-after'];
    final seconds = header == null ? null : int.tryParse(header);
    final delay = Duration(seconds: seconds ?? 4);
    return delay > const Duration(seconds: 15)
        ? const Duration(seconds: 15)
        : delay;
  }

  static String _extractText(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw const GeminiException(GeminiErrorType.other, '응답이 비어 있음');
      }
      final content =
          (candidates.first as Map<String, dynamic>)['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final text = parts
          ?.map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
          .join()
          .trim();
      if (text == null || text.isEmpty) {
        throw const GeminiException(GeminiErrorType.other, '텍스트 없는 응답');
      }
      return text;
    } on GeminiException {
      rethrow;
    } catch (e) {
      throw GeminiException(GeminiErrorType.other, '응답 파싱 실패: $e');
    }
  }

  static String _errorMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return ((json['error'] as Map<String, dynamic>?)?['message'] as String?) ??
          body;
    } catch (_) {
      return body;
    }
  }

  void dispose() => _http.close();
}
