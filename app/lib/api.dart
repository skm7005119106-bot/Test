import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Where the backend lives. Set it when building:
/// `flutter build apk --dart-define=KAYRA_API=https://your-server.example`
const kayraApiUrl = String.fromEnvironment('KAYRA_API', defaultValue: 'http://10.0.2.2:8080');

/// The server answered with an error.
class ApiException implements Exception {
  const ApiException(this.status, this.code);

  final int status;
  final String code;

  @override
  String toString() => 'ApiException($status, $code)';
}

/// The session is gone (signed out elsewhere, or the account was deleted).
class SignedOut extends ApiException {
  const SignedOut() : super(401, 'signed_out');
}

/// Today's messages are used up.
class DailyLimitReached extends ApiException {
  const DailyLimitReached() : super(429, 'daily_limit');
}

/// The phone could not reach the server.
class NetworkFailure implements Exception {}

abstract class KayraApi {
  /// The session token sent with every request once signed in.
  String? token;

  Future<SignInResult> signInWithGoogle(String idToken);
  Future<Me> loadMe();
  Future<Me> updateProfile({String? name, String? nickname, String? mood});
  Future<ChatResult> sendChat(String text);
  Future<void> react(int messageId, String? emoji);
  Future<void> report(int messageId, String reason);
  Future<MemoryList> deleteMemory(int id);
  Future<void> clearChat();
  Future<void> signOut();
  Future<void> deleteAccount();
  Future<Me> verifyPurchase({required String productId, required String purchaseToken});
}

class HttpKayraApi implements KayraApi {
  HttpKayraApi({http.Client? client, this.baseUrl = kayraApiUrl}) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  @override
  String? token;

  Future<Map<String, dynamic>> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);

    http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 60)),
      );
    } catch (_) {
      throw NetworkFailure();
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      json = {};
    }
    if (response.statusCode == 200) return json;
    final code = json['error'] as String? ?? 'server_error';
    if (response.statusCode == 401 && path != '/auth/google') throw const SignedOut();
    if (response.statusCode == 429 && code == 'daily_limit') throw const DailyLimitReached();
    throw ApiException(response.statusCode, code);
  }

  @override
  Future<SignInResult> signInWithGoogle(String idToken) async {
    final json = await _send('POST', '/auth/google', {'idToken': idToken});
    token = json['token'] as String;
    return SignInResult(
      token: token!,
      suggestedName: json['suggestedName'] as String? ?? '',
      me: Me.fromJson(json['me'] as Map<String, dynamic>),
    );
  }

  @override
  Future<Me> loadMe() async => Me.fromJson(await _send('GET', '/me'));

  @override
  Future<Me> updateProfile({String? name, String? nickname, String? mood}) async => Me.fromJson(
        await _send('PATCH', '/me', {
          'name': ?name,
          'nickname': ?nickname,
          'mood': ?mood,
        }),
      );

  @override
  Future<ChatResult> sendChat(String text) async =>
      ChatResult.fromJson(await _send('POST', '/chat', {'text': text}));

  @override
  Future<void> react(int messageId, String? emoji) =>
      _send('PUT', '/messages/$messageId/reaction', {'emoji': emoji});

  @override
  Future<void> report(int messageId, String reason) =>
      _send('POST', '/report', {'messageId': messageId, 'reason': reason});

  @override
  Future<MemoryList> deleteMemory(int id) async => MemoryList.fromJson(await _send('DELETE', '/memories/$id'));

  @override
  Future<void> clearChat() => _send('DELETE', '/me/messages');

  @override
  Future<void> signOut() async {
    try {
      await _send('POST', '/auth/sign-out');
    } finally {
      token = null;
    }
  }

  @override
  Future<void> deleteAccount() async {
    await _send('DELETE', '/me');
    token = null;
  }

  @override
  Future<Me> verifyPurchase({required String productId, required String purchaseToken}) async => Me.fromJson(
        await _send('POST', '/billing/google-play', {'productId': productId, 'purchaseToken': purchaseToken}),
      );
}
