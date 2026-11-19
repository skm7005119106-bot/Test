import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kayra/api.dart';
import 'package:kayra/controller.dart';
import 'package:kayra/main.dart';
import 'package:kayra/models.dart';
import 'package:kayra/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---- Fakes ----

Map<String, dynamic> progressJson(int xp, {int streak = 1}) {
  const starts = [0, 40, 120, 280, 600];
  var level = 0;
  for (var i = 0; i < starts.length; i++) {
    if (xp >= starts[i]) level = i;
  }
  return {
    'xp': xp,
    'level': level,
    'levelName': levelNames[level],
    'levelStart': starts[level],
    'nextAt': level + 1 < starts.length ? starts[level + 1] : null,
    'streak': streak,
  };
}

class FakeApi implements KayraApi {
  @override
  String? token;

  String name = '';
  String nickname = '';
  String mood = 'sweet';
  int xp = 0;
  int remaining = 30;
  bool plus = false;
  bool limitReached = false;
  bool sessionExpired = false;
  int _nextId = 1;
  final messages = <Map<String, dynamic>>[];
  var memories = <Map<String, dynamic>>[
    {'id': 1, 'fact': 'Pune me rehta hai'},
    {'id': 2, 'fact': 'Chai pasand hai'},
  ];
  final reactions = <int, String?>{};
  final reports = <int>[];
  final purchases = <String>[];
  bool deleted = false;

  Map<String, dynamic> _message(String role, String text) =>
      {'id': _nextId++, 'role': role, 'text': text, 'reaction': null, 'time': DateTime(2026, 11, 19, 21, 5).millisecondsSinceEpoch};

  Map<String, dynamic> get _meJson => {
        'profile': {'name': name, 'nickname': nickname, 'mood': mood, 'email': 'aman@example.com'},
        'progress': progressJson(xp),
        'plus': {'active': plus, 'until': plus ? DateTime(2026, 12, 19).millisecondsSinceEpoch : null, 'productId': null},
        'usage': {'limit': plus ? 300 : 30, 'remaining': remaining},
        'memory': {'items': memories, 'limit': plus ? 40 : 20},
        'messages': messages,
        'purchaseAccountId': 'acct-123',
      };

  void _check() {
    if (sessionExpired) throw const SignedOut();
  }

  @override
  Future<SignInResult> signInWithGoogle(String idToken) async {
    token = 'session-token';
    return SignInResult(token: token!, suggestedName: 'Aman', me: Me.fromJson(_meJson));
  }

  @override
  Future<Me> loadMe() async {
    _check();
    return Me.fromJson(_meJson);
  }

  @override
  Future<Me> updateProfile({String? name, String? nickname, String? mood}) async {
    _check();
    if (this.name.isEmpty && name != null) {
      messages.add(_message('assistant', 'Hii ${nickname?.isNotEmpty == true ? nickname : name}! Main Kayra 💕'));
    }
    this.name = name ?? this.name;
    this.nickname = nickname ?? this.nickname;
    this.mood = mood ?? this.mood;
    return Me.fromJson(_meJson);
  }

  @override
  Future<ChatResult> sendChat(String text) async {
    _check();
    if (limitReached) throw const DailyLimitReached();
    final sent = _message('user', text);
    final reply = _message('assistant', 'Aww, "$text"? 😄');
    messages.addAll([sent, reply]);
    final before = progressJson(xp)['level'] as int;
    xp += 10;
    remaining -= 1;
    final after = progressJson(xp)['level'] as int;
    return ChatResult.fromJson({
      'sent': sent,
      'reply': reply,
      'suggestions': ['Haan na', 'Tum batao', 'Miss kiya'],
      'progress': progressJson(xp),
      'levelUp': after > before ? levelNames[after] : null,
      'usage': {'limit': 30, 'remaining': remaining},
    });
  }

  @override
  Future<void> react(int messageId, String? emoji) async => reactions[messageId] = emoji;

  @override
  Future<void> report(int messageId, String reason) async => reports.add(messageId);

  @override
  Future<MemoryList> deleteMemory(int id) async {
    memories = memories.where((m) => m['id'] != id).toList();
    return MemoryList.fromJson({'items': memories, 'limit': 20});
  }

  @override
  Future<void> clearChat() async => messages.clear();

  @override
  Future<void> signOut() async => token = null;

  @override
  Future<void> deleteAccount() async {
    deleted = true;
    token = null;
  }

  @override
  Future<Me> verifyPurchase({required String productId, required String purchaseToken}) async {
    purchases.add('$productId:$purchaseToken');
    plus = true;
    return Me.fromJson(_meJson);
  }
}

class FakeAuth implements AuthService {
  bool signedOut = false;

  @override
  Future<String?> signIn() async => 'google-id-token';

  @override
  Future<void> signOut() async => signedOut = true;
}

class FakeBilling implements BillingService {
  final _updates = StreamController<PurchaseUpdate>.broadcast();
  final bought = <String>[];
  final finished = <PurchaseUpdate>[];

  @override
  Stream<PurchaseUpdate> get updates => _updates.stream;

  @override
  Future<List<Plan>> loadPlans() async => const [
        Plan(id: 'kayra_plus_monthly', price: '₹149', yearly: false),
        Plan(id: 'kayra_plus_yearly', price: '₹999', yearly: true),
      ];

  @override
  Future<void> buy(Plan plan, {required String accountId}) async {
    bought.add('${plan.id}:$accountId');
    _updates.add(PurchaseUpdate(PurchaseUpdateKind.purchased, productId: plan.id, purchaseToken: 'play-token'));
  }

  @override
  Future<void> restore({required String accountId}) async {}

  @override
  Future<void> finish(PurchaseUpdate update) async => finished.add(update);
}

class Harness {
  Harness(this.api, this.auth, this.billing, this.controller);
  final FakeApi api;
  final FakeAuth auth;
  final FakeBilling billing;
  final KayraController controller;
}

Future<Harness> pumpApp(WidgetTester tester, {FakeApi? api, Map<String, Object> saved = const {}}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.7;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(saved);
  final fakeApi = api ?? FakeApi();
  final auth = FakeAuth();
  final billing = FakeBilling();
  final controller = KayraController(api: fakeApi, auth: auth, billing: billing, session: await SessionStore.open());
  await tester.pumpWidget(KayraApp(controller: controller));
  await controller.start();
  await tester.pumpAndSettle();
  return Harness(fakeApi, auth, billing, controller);
}

Future<void> signInAndSetUp(WidgetTester tester) async {
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
  await tester.tap(find.text('Google se continue karo'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Kayra tumhe kya bulaye? (optional)'), 'Jaan');
  await tester.tap(find.text('Kayra se milo'));
  await tester.pumpAndSettle();
}

Future<void> sendMessage(WidgetTester tester, String text) async {
  await tester.enterText(find.widgetWithText(TextField, 'Message likho...'), text);
  await tester.tap(find.bySemanticsLabel('Bhejo'));
  await tester.pumpAndSettle();
}

FakeApi readyApi() => FakeApi()
  ..name = 'Aman'
  ..nickname = 'Jaan'
  ..messages.add({'id': 100, 'role': 'assistant', 'text': 'Hii Jaan! Main Kayra 💕', 'reaction': null, 'time': 0});

const savedSession = {'session': 'session-token'};

void main() {
  // Use the app's real fonts, so text takes the space it takes on a phone.
  setUpAll(() async {
    for (final (family, weights) in [('Inter', [400, 500, 600]), ('Sora', [600, 700, 800])]) {
      final loader = FontLoader(family);
      for (final w in weights) {
        loader.addFont(rootBundle.load('assets/fonts/$family-$w.ttf'));
      }
      await loader.load();
    }
  });

  testWidgets('signing in needs the 18+ confirmation, then asks for a name', (tester) async {
    final h = await pumpApp(tester);
    expect(find.textContaining('AI character hai'), findsOneWidget);

    await tester.tap(find.text('Google se continue karo'));
    await tester.pump();
    expect(find.text('Kayra se milo'), findsNothing);

    await signInAndSetUp(tester);
    expect(find.text('Hii Jaan! Main Kayra 💕'), findsOneWidget);
    expect(find.text('AI • online'), findsOneWidget);
    expect(h.api.name, 'Aman');
    expect(h.api.nickname, 'Jaan');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('session'), 'session-token');
  });

  testWidgets('chatting shows replies, suggestions, progress and a level-up', (tester) async {
    final h = await pumpApp(tester, api: readyApi(), saved: savedSession);
    expect(find.text('Stranger'), findsOneWidget);
    expect(find.text('Bas theek tha'), findsOneWidget);

    await sendMessage(tester, 'kya kar rahi ho?');
    expect(find.text('kya kar rahi ho?'), findsOneWidget);
    expect(find.text('Aww, "kya kar rahi ho?"? 😄'), findsOneWidget);
    expect(find.text('Haan na'), findsOneWidget);
    expect(find.text('10 / 40 ❤'), findsOneWidget);

    for (final t in ['ek', 'do']) {
      await sendMessage(tester, t);
    }
    await tester.tap(find.text('Haan na'));
    await tester.pumpAndSettle();
    expect(find.text('Dost'), findsOneWidget);
    expect(find.text('Level up! Ab tum dono ka rishta: Dost 💖'), findsOneWidget);
    expect(h.api.messages.where((m) => m['role'] == 'user').length, 4);
  });

  testWidgets('running out of free messages opens Kayra Plus and keeps the text', (tester) async {
    final api = readyApi()..limitReached = true;
    await pumpApp(tester, api: api, saved: savedSession);
    await sendMessage(tester, 'hello');
    expect(find.textContaining('Aaj ke free messages khatam ho gaye'), findsOneWidget);
    expect(find.text('₹149'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'hello'), findsOneWidget);
  });

  testWidgets('locked moods explain how to unlock them', (tester) async {
    final h = await pumpApp(tester, api: readyApi(), saved: savedSession);
    await tester.tap(find.text('😜 Funny'));
    await tester.pumpAndSettle();
    expect(h.api.mood, 'funny');

    await tester.tap(find.text('😏 Flirty 🔒'));
    await tester.pump();
    expect(find.textContaining('Crush level par khulega'), findsOneWidget);
    expect(h.api.mood, 'funny');

    await tester.drag(find.text('😜 Funny'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🙈 Shy 🔒'));
    await tester.pumpAndSettle();
    expect(find.text('Kayra Plus lo'), findsOneWidget);
  });

  testWidgets('reacting to and reporting a Kayra message', (tester) async {
    final h = await pumpApp(tester, api: readyApi(), saved: savedSession);
    await tester.tap(find.text('Hii Jaan! Main Kayra 💕'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('React ❤️').first);
    await tester.pumpAndSettle();
    expect(h.api.reactions[100], '❤️');
    expect(find.text('❤️'), findsOneWidget);

    await tester.longPress(find.text('Hii Jaan! Main Kayra 💕'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Is message ko report karo'));
    await tester.pumpAndSettle();
    expect(h.api.reports, [100]);
    expect(find.text('Report bhej diya. Shukriya!'), findsOneWidget);
  });

  testWidgets('Kayra\'s profile shows her photos with level and Plus locks', (tester) async {
    await pumpApp(tester, api: readyApi(), saved: savedSession);
    await tester.tap(find.text('Kayra').first);
    await tester.pumpAndSettle();
    expect(find.text('Kayra, 22'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('🔒 Kayra Plus'), 300);
    expect(find.text('🔒 Crush level par'), findsOneWidget);
    expect(find.text('🔒 Girlfriend level par'), findsOneWidget);
  });

  testWidgets('buying Kayra Plus verifies the purchase with the server first', (tester) async {
    final h = await pumpApp(tester, api: readyApi(), saved: savedSession);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kayra Plus lo'));
    await tester.pumpAndSettle();

    expect(find.text('BEST VALUE'), findsOneWidget);
    await tester.tap(find.text('Monthly'));
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, 'Kayra Plus lo'));
    await tester.pumpAndSettle();

    expect(h.billing.bought, ['kayra_plus_monthly:acct-123']);
    expect(h.api.purchases, ['kayra_plus_monthly:play-token']);
    expect(h.billing.finished.length, 1);
    expect(find.text('Tum Kayra Plus member ho 💖'), findsOneWidget);
    expect(find.text('Welcome to Kayra Plus 💖'), findsOneWidget);
  });

  testWidgets('memories can be forgotten from settings', (tester) async {
    final h = await pumpApp(tester, api: readyApi(), saved: savedSession);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('2 baatein yaad hain'), findsOneWidget);
    await tester.tap(find.text('Kayra ki yaadein'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 20 yaadein • Kayra Plus me 40'), findsOneWidget);
    await tester.tap(find.byTooltip('Bhool jao').first);
    await tester.pumpAndSettle();
    expect(find.text('Pune me rehta hai'), findsNothing);
    expect(find.text('Chai pasand hai'), findsOneWidget);
    expect(h.api.memories.length, 1);
  });

  testWidgets('deleting the account returns to sign-in', (tester) async {
    final h = await pumpApp(tester, api: readyApi(), saved: savedSession);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Account delete karo'), 200);
    await tester.tap(find.text('Account delete karo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete karo'));
    await tester.pumpAndSettle();

    expect(h.api.deleted, isTrue);
    expect(h.auth.signedOut, isTrue);
    expect(find.text('Google se continue karo'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('session'), isNull);
  });

  testWidgets('an expired session goes back to sign-in', (tester) async {
    final api = readyApi()..sessionExpired = true;
    await pumpApp(tester, api: api, saved: savedSession);
    expect(find.text('Google se continue karo'), findsOneWidget);
  });

  group('HttpKayraApi', () {
    test('signs in, then sends the session token', () async {
      final seen = <String?>[];
      final api = HttpKayraApi(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          seen.add(request.headers['Authorization']);
          if (request.url.path == '/auth/google') {
            expect(jsonDecode(request.body), {'idToken': 'google-id'});
            return http.Response.bytes(
              utf8.encode(jsonEncode({'token': 'tok_1234567890', 'suggestedName': 'Aman', 'me': FakeApi()._meJson})),
              200,
            );
          }
          return http.Response.bytes(utf8.encode(jsonEncode((FakeApi()..name = 'Aman')._meJson)), 200);
        }),
      );
      final result = await api.signInWithGoogle('google-id');
      expect(result.suggestedName, 'Aman');
      final me = await api.loadMe();
      expect(me.profile.name, 'Aman');
      expect(seen, [null, 'Bearer tok_1234567890']);
    });

    test('maps errors', () async {
      HttpKayraApi returning(int status, String code) => HttpKayraApi(
            baseUrl: 'http://test',
            client: MockClient((_) async => http.Response(jsonEncode({'error': code}), status)),
          )..token = 'tok_1234567890';

      expect(returning(401, 'signed_out').loadMe(), throwsA(isA<SignedOut>()));
      expect(returning(429, 'daily_limit').sendChat('hi'), throwsA(isA<DailyLimitReached>()));
      expect(
        returning(403, 'mood_locked').updateProfile(mood: 'shy'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'mood_locked')),
      );
      final offline = HttpKayraApi(baseUrl: 'http://test', client: MockClient((_) => throw Exception('no network')));
      expect(offline.loadMe(), throwsA(isA<NetworkFailure>()));
    });
  });
}
