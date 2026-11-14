import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Where the backend lives. Set it when building:
/// `flutter build apk --dart-define=KAYRA_API=https://your-server.example`
const kayraApiUrl =
    String.fromEnvironment('KAYRA_API', defaultValue: 'http://10.0.2.2:8080');

class ChatResult {
  const ChatResult({required this.reply, required this.remaining, this.memory});

  final String reply;
  final int remaining;

  /// A refreshed memory list, sent by the server every few messages.
  final List<String>? memory;
}

/// Today's free messages are used up.
class DailyLimitReached implements Exception {}

/// The server or the network failed; the message can be sent again.
class ApiFailure implements Exception {}

abstract class KayraApi {
  Future<ChatResult> sendChat({
    required String deviceId,
    required Profile profile,
    required List<String> memory,
    required List<ChatMessage> messages,
  });

  Future<void> report({
    required String deviceId,
    required String message,
    required String reason,
  });
}

class HttpKayraApi implements KayraApi {
  HttpKayraApi({http.Client? client, this.baseUrl = kayraApiUrl})
      : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  /// How many recent messages go to the server with each request.
  static const historyLimit = 40;

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    try {
      return await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw ApiFailure();
    }
  }

  @override
  Future<ChatResult> sendChat({
    required String deviceId,
    required Profile profile,
    required List<String> memory,
    required List<ChatMessage> messages,
  }) async {
    final recent = messages.length > historyLimit
        ? messages.sublist(messages.length - historyLimit)
        : messages;
    final response = await _post('/chat', {
      'deviceId': deviceId,
      'profile': profile.toJson(),
      'memory': memory,
      'messages': [
        for (final m in recent)
          {'role': m.fromUser ? 'user' : 'assistant', 'text': m.text},
      ],
    });
    if (response.statusCode == 429) throw DailyLimitReached();
    if (response.statusCode != 200) throw ApiFailure();
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return ChatResult(
      reply: body['reply'] as String,
      remaining: body['remaining'] as int,
      memory: (body['memory'] as List?)?.cast<String>(),
    );
  }

  @override
  Future<void> report({
    required String deviceId,
    required String message,
    required String reason,
  }) async {
    final response = await _post(
        '/report', {'deviceId': deviceId, 'message': message, 'reason': reason});
    if (response.statusCode != 200) throw ApiFailure();
  }
}
