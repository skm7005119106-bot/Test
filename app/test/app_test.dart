import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kayra/api.dart';
import 'package:kayra/main.dart';
import 'package:kayra/models.dart';
import 'package:kayra/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeApi implements KayraApi {
  bool limitReached = false;
  List<String>? memoryToReturn;
  final sent = <List<ChatMessage>>[];
  final reports = <String>[];

  @override
  Future<ChatResult> sendChat({
    required String deviceId,
    required Profile profile,
    required List<String> memory,
    required List<ChatMessage> messages,
  }) async {
    if (limitReached) throw DailyLimitReached();
    sent.add(messages);
    return ChatResult(
        reply: 'Aww ${profile.callName} 💕', remaining: 3, memory: memoryToReturn);
  }

  @override
  Future<void> report({
    required String deviceId,
    required String message,
    required String reason,
  }) async {
    reports.add(message);
  }
}

Future<Storage> pumpApp(WidgetTester tester, FakeApi api,
    {Map<String, Object> saved = const {}}) async {
  SharedPreferences.setMockInitialValues(saved);
  final storage = await Storage.open();
  await tester.pumpWidget(KayraApp(storage: storage, api: api));
  return storage;
}

Future<void> onboard(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextField, 'Tumhara naam'), 'Aman');
  await tester.enterText(
      find.widgetWithText(TextField, 'Kayra tumhe kya bulaye? (optional)'), 'Jaan');
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
  await tester.tap(find.text('Kayra se baat karo'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cannot start without a name and the 18+ confirmation', (tester) async {
    await pumpApp(tester, FakeApi());
    FilledButton start() => tester.widget(find.byType(FilledButton));

    expect(start().onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Tumhara naam'), 'Aman');
    await tester.pump();
    expect(start().onPressed, isNull);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(start().onPressed, isNotNull);
  });

  testWidgets('onboarding opens the chat with a greeting, and a message gets a reply',
      (tester) async {
    final api = FakeApi()..memoryToReturn = ['Naam Aman hai'];
    final storage = await pumpApp(tester, api);
    await onboard(tester);

    expect(find.textContaining('Hii Jaan!'), findsOneWidget);
    expect(find.textContaining('AI companion'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'kya kar rahi ho?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('kya kar rahi ho?'), findsOneWidget);
    expect(find.text('Aww Jaan 💕'), findsOneWidget);
    expect(find.text('Aaj ke 3 free messages bache hain'), findsOneWidget);
    expect(api.sent.single.last.text, 'kya kar rahi ho?');
    expect(storage.messages.length, 3);
    expect(storage.memory, ['Naam Aman hai']);
  });

  testWidgets('hitting the daily limit shows the Kayra Plus sheet', (tester) async {
    final api = FakeApi()..limitReached = true;
    await pumpApp(tester, api);
    await onboard(tester);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Kayra Plus jald aa raha hai'), findsOneWidget);
  });

  testWidgets('a Kayra message can be reported', (tester) async {
    final api = FakeApi();
    await pumpApp(tester, api);
    await onboard(tester);

    await tester.longPress(find.textContaining('Hii Jaan!'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Is message ko report karo'));
    await tester.pumpAndSettle();

    expect(api.reports.single, contains('Hii Jaan!'));
    expect(find.text('Report bhej diya. Shukriya!'), findsOneWidget);
  });

  testWidgets('deleting data returns to onboarding', (tester) async {
    final storage = await pumpApp(tester, FakeApi());
    await onboard(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mera data delete karo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete karo'));
    await tester.pumpAndSettle();

    expect(find.text('Kayra se baat karo'), findsOneWidget);
    expect(storage.profile, isNull);
    expect(storage.messages, isEmpty);
  });

  test('the HTTP client sends the chat and reads the reply', () async {
    late Map<String, dynamic> received;
    final api = HttpKayraApi(
      baseUrl: 'http://test',
      client: MockClient((request) async {
        received = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response.bytes(
          utf8.encode(jsonEncode({'reply': 'Hii 💕', 'remaining': 7, 'limit': 30})),
          200,
        );
      }),
    );
    final result = await api.sendChat(
      deviceId: 'device_1234567890abcdef',
      profile: const Profile(name: 'Aman', nickname: ''),
      memory: const ['Chai pasand hai'],
      messages: [
        ChatMessage(fromUser: false, text: 'Hii'),
        ChatMessage(fromUser: true, text: 'hello'),
      ],
    );

    expect(result.reply, 'Hii 💕');
    expect(result.remaining, 7);
    expect(received['messages'], [
      {'role': 'assistant', 'text': 'Hii'},
      {'role': 'user', 'text': 'hello'},
    ]);
    expect(received['memory'], ['Chai pasand hai']);
  });

  test('the HTTP client maps 429 to DailyLimitReached and 5xx to ApiFailure', () async {
    HttpKayraApi apiReturning(int status) => HttpKayraApi(
        baseUrl: 'http://test',
        client: MockClient((_) async => http.Response('{}', status)));
    Future<ChatResult> send(HttpKayraApi api) => api.sendChat(
          deviceId: 'device_1234567890abcdef',
          profile: const Profile(name: 'Aman', nickname: ''),
          memory: const [],
          messages: [ChatMessage(fromUser: true, text: 'hi')],
        );

    expect(send(apiReturning(429)), throwsA(isA<DailyLimitReached>()));
    expect(send(apiReturning(502)), throwsA(isA<ApiFailure>()));
  });
}
