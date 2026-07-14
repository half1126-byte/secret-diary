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

  /// 기본은 Google 공식 엔드포인트. 테스트/데모에서만
  /// --dart-define=GEMINI_BASE_URL=... 로 바꿀 수 있다.
  static const _base = String.fromEnvironment(
    'GEMINI_BASE_URL',
    defaultValue: 'https://generativelanguage.googleapis.com/v1beta',
  );

  /// 대화를 보내고 답장 텍스트를 받는다.
  ///
  /// [imagePngBase64]가 있으면 마지막 사용자 턴에 스케치 이미지를 붙인다
  /// (아이디어 모드 — 그림을 보고 해석).
  Future<String> generateReply({
    required String apiKey,
    required String model,
    required BuiltPrompt prompt,
    String? imagePngBase64,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const GeminiException(GeminiErrorType.noApiKey);
    }

    final uri = Uri.parse('$_base/models/$model:generateContent');
    final body = _requestBody(prompt, imagePngBase64);

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

      if (response.statusCode == 200) {
        // 서버 charset 헤더와 무관하게 UTF-8로 해석한다.
        return _extractText(
            utf8.decode(response.bodyBytes, allowMalformed: true));
      }
      if ((response.statusCode == 429 || response.statusCode == 503) &&
          attempt < maxRetries) {
        await Future<void>.delayed(
            _retryDelay(response.headers['retry-after']));
        continue;
      }
      _throwForStatus(response.statusCode, response.body, model);
    }
  }

  /// 답장을 스트리밍으로 받는다 — 첫 글자가 도착하는 즉시 보여줄 수 있어
  /// 체감 속도가 크게 빨라진다. 누적된 전체 텍스트를 매번 내보낸다.
  ///
  /// 서버가 SSE가 아닌 일반 JSON으로 응답하면(테스트·모의 서버) 전체를
  /// 한 번에 내보내는 폴백으로 동작한다.
  Stream<String> generateReplyStream({
    required String apiKey,
    required String model,
    required BuiltPrompt prompt,
    String? imagePngBase64,
  }) async* {
    if (apiKey.trim().isEmpty) {
      throw const GeminiException(GeminiErrorType.noApiKey);
    }

    final uri =
        Uri.parse('$_base/models/$model:streamGenerateContent?alt=sse');
    final body = _requestBody(prompt, imagePngBase64);

    for (var attempt = 0; ; attempt++) {
      http.StreamedResponse response;
      try {
        final request = http.Request('POST', uri)
          ..headers['Content-Type'] = 'application/json'
          ..headers['x-goog-api-key'] = apiKey
          ..body = body;
        response = await _http.send(request);
      } on Exception catch (e) {
        throw GeminiException(GeminiErrorType.network, e.toString());
      }

      if (response.statusCode != 200) {
        final errorBody =
            utf8.decode(await response.stream.toBytes(), allowMalformed: true);
        if ((response.statusCode == 429 || response.statusCode == 503) &&
            attempt < maxRetries) {
          await Future<void>.delayed(
              _retryDelay(response.headers['retry-after']));
          continue;
        }
        _throwForStatus(response.statusCode, errorBody, model);
      }

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('text/event-stream')) {
        yield _extractText(
            utf8.decode(await response.stream.toBytes(), allowMalformed: true));
        return;
      }

      var accumulated = '';
      Stream<String> lines;
      try {
        lines = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());
        await for (final line in lines) {
          if (!line.startsWith('data:')) continue;
          final data = line.substring(5).trim();
          if (data.isEmpty || data == '[DONE]') continue;
          final delta = _tryExtractText(data);
          if (delta.isEmpty) continue;
          accumulated += delta;
          yield accumulated;
        }
      } on GeminiException {
        rethrow;
      } on Exception catch (e) {
        // 이미 받은 텍스트가 있으면 살리고, 아니면 네트워크 오류로.
        if (accumulated.trim().isEmpty) {
          throw GeminiException(GeminiErrorType.network, e.toString());
        }
        return;
      }
      if (accumulated.trim().isEmpty) {
        throw const GeminiException(GeminiErrorType.other, '텍스트 없는 응답');
      }
      return;
    }
  }

  static String _requestBody(BuiltPrompt prompt, String? imagePngBase64) {
    final turns = prompt.turns;
    final lastUserIndex =
        turns.lastIndexWhere((turn) => turn.role == 'user');
    return jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': prompt.systemInstruction},
        ],
      },
      'contents': [
        for (var i = 0; i < turns.length; i++)
          {
            'role': turns[i].role,
            'parts': [
              if (imagePngBase64 != null && i == lastUserIndex)
                {
                  'inline_data': {
                    'mime_type': 'image/png',
                    'data': imagePngBase64,
                  },
                },
              {'text': turns[i].text},
            ],
          },
      ],
      'generationConfig': {
        'temperature': 0.9,
        // 최신 모델은 내부 사고(thinking) 토큰도 이 한도에 포함될 수 있어 여유 있게.
        'maxOutputTokens': 2048,
        // 빠른 답변: 내부 사고를 생략한다. 설정의 모델이 전부 flash 계열이라
        // 안전하다 (pro 계열은 0을 허용하지 않음).
        'thinkingConfig': {'thinkingBudget': 0},
      },
    });
  }

  /// 200이 아닌 응답을 사용자 친화적 오류로 바꿔 던진다.
  static Never _throwForStatus(int statusCode, String body, String model) {
    switch (statusCode) {
      case 401:
      case 403:
        throw GeminiException(
            GeminiErrorType.invalidApiKey, _errorMessage(body));
      case 400:
        // 400은 대개 요청 자체의 문제다. 키 문제로 명시된 경우만 키 오류로.
        final message = _errorMessage(body);
        if (_errorStatus(body) == 'API_KEY_INVALID' ||
            message.contains('API key not valid')) {
          throw GeminiException(GeminiErrorType.invalidApiKey, message);
        }
        throw GeminiException(GeminiErrorType.other, '잘못된 요청: $message');
      case 404:
        throw GeminiException(
            GeminiErrorType.other, '모델($model)을 찾을 수 없어요 — 설정에서 모델을 확인해 주세요.');
      case 429:
      case 503:
        throw GeminiException(GeminiErrorType.rateLimited, _errorMessage(body));
      default:
        throw GeminiException(
          GeminiErrorType.other,
          'HTTP $statusCode: ${_errorMessage(body)}',
        );
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

  static Duration _retryDelay(String? retryAfterHeader) {
    final seconds =
        retryAfterHeader == null ? null : int.tryParse(retryAfterHeader);
    final delay = Duration(seconds: seconds ?? 4);
    return delay > const Duration(seconds: 15)
        ? const Duration(seconds: 15)
        : delay;
  }

  /// 스트림 청크에서 텍스트 델타를 꺼낸다. 없으면 빈 문자열
  /// (마지막 usage 전용 청크 등은 조용히 무시).
  static String _tryExtractText(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return '';
      final content = (candidates.first as Map<String, dynamic>)['content']
          as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      return parts
              ?.map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
              .join() ??
          '';
    } catch (_) {
      return '';
    }
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

  /// Google API 오류 응답의 `error.status` (예: 'API_KEY_INVALID', 'INVALID_ARGUMENT').
  static String? _errorStatus(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      final status = error?['status'] as String?;
      if (status != null) return status;
      // 상세 reason에 담겨 오는 경우도 있다.
      final details = error?['details'] as List<dynamic>?;
      for (final d in details ?? const []) {
        final reason = (d as Map<String, dynamic>)['reason'] as String?;
        if (reason != null) return reason;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _http.close();
}
