import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'models.dart';
import 'services.dart';

enum Phase { loading, offline, signedOut, needsProfile, ready }

/// A notice shown in the chat after a message, such as a level-up. Not stored on the server.
class ChatEvent {
  const ChatEvent(this.afterMessageId, this.text);
  final int afterMessageId;
  final String text;
}

/// Holds the signed-in user's state and talks to the server, Google and the Play Store.
class KayraController extends ChangeNotifier {
  KayraController({required this.api, required this.auth, required this.billing, required this.session}) {
    _purchases = billing.updates.listen(_onPurchase);
  }

  final KayraApi api;
  final AuthService auth;
  final BillingService billing;
  final SessionStore session;
  late final StreamSubscription<PurchaseUpdate> _purchases;

  Phase phase = Phase.loading;
  Me? me;
  String suggestedName = '';
  List<String> suggestions = const ['Bas theek tha', 'Tumhe miss kiya', 'Tum batao pehle'];
  final List<ChatEvent> events = [];
  bool typing = false;
  String? pendingText;

  // Kayra Plus
  List<Plan>? plans;
  bool buying = false;
  String? purchaseNotice;

  Me get user => me!;

  @override
  void dispose() {
    _purchases.cancel();
    super.dispose();
  }

  void _setMe(Me value) {
    // Opening an ongoing chat: the first-greeting suggestions no longer fit.
    if (me == null && value.messages.length > 1) {
      suggestions = const ['Haan 😊', 'Aur batao', 'Tum kya kar rahi ho?'];
    }
    me = value;
    phase = value.needsProfile ? Phase.needsProfile : Phase.ready;
    notifyListeners();
  }

  Future<void> _signedOutLocally() async {
    api.token = null;
    await session.clear();
    me = null;
    events.clear();
    phase = Phase.signedOut;
    notifyListeners();
  }

  /// Runs [action], sending the user back to sign-in if their session has ended.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SignedOut {
      await _signedOutLocally();
      rethrow;
    }
  }

  // ---- Start-up and sign-in ----

  Future<void> start() async {
    final token = session.token;
    if (token == null) {
      phase = Phase.signedOut;
      notifyListeners();
      return;
    }
    api.token = token;
    phase = Phase.loading;
    notifyListeners();
    try {
      _setMe(await api.loadMe());
      unawaited(restorePurchases());
    } on SignedOut {
      await _signedOutLocally();
    } on NetworkFailure {
      phase = Phase.offline;
      notifyListeners();
    } on ApiException {
      phase = Phase.offline;
      notifyListeners();
    }
  }

  /// Returns false when the user closed the Google account picker.
  Future<bool> signInWithGoogle() async {
    final idToken = await auth.signIn();
    if (idToken == null) return false;
    final result = await api.signInWithGoogle(idToken);
    await session.save(result.token);
    suggestedName = result.suggestedName;
    _setMe(result.me);
    unawaited(restorePurchases());
    return true;
  }

  Future<void> completeProfile({required String name, required String nickname}) async {
    _setMe(await _guard(() => api.updateProfile(name: name, nickname: nickname)));
  }

  Future<void> updateNames({required String name, required String nickname}) async {
    _setMe(await _guard(() => api.updateProfile(name: name, nickname: nickname)));
  }

  // ---- Chat ----

  /// Sends a message. Throws [DailyLimitReached], [NetworkFailure] or [ApiException];
  /// on failure nothing is added to the chat.
  Future<void> send(String text) async {
    text = text.trim();
    if (text.isEmpty || typing) return;
    pendingText = text;
    typing = true;
    notifyListeners();
    try {
      final result = await _guard(() => api.sendChat(text));
      me = user.copyWith(
        messages: [...user.messages, result.sent, result.reply],
        progress: result.progress,
        usage: result.usage,
      );
      suggestions = result.suggestions;
      if (result.levelUp != null) {
        events.add(ChatEvent(result.reply.id, 'Level up! Ab tum dono ka rishta: ${result.levelUp} 💖'));
      }
    } on DailyLimitReached {
      me = user.copyWith(usage: Usage(limit: user.usage.limit, remaining: 0));
      rethrow;
    } finally {
      typing = false;
      pendingText = null;
      notifyListeners();
    }
  }

  Future<void> react(Message message, String? emoji) async {
    final previous = message.reaction;
    _replaceMessage(message.withReaction(emoji));
    try {
      await _guard(() => api.react(message.id, emoji));
    } catch (_) {
      _replaceMessage(message.withReaction(previous));
      rethrow;
    }
  }

  void _replaceMessage(Message updated) {
    me = user.copyWith(messages: [for (final m in user.messages) m.id == updated.id ? updated : m]);
    notifyListeners();
  }

  Future<void> report(Message message, String reason) => _guard(() => api.report(message.id, reason));

  /// Throws [ApiException] with code `mood_locked` if the server refuses.
  Future<void> setMood(String mood) async {
    _setMe(await _guard(() => api.updateProfile(mood: mood)));
  }

  // ---- Memories ----

  Future<void> forget(Memory memory) async {
    final list = await _guard(() => api.deleteMemory(memory.id));
    me = user.copyWith(memory: list);
    notifyListeners();
  }

  // ---- Account ----

  Future<void> clearChat() async {
    await _guard(api.clearChat);
    events.clear();
    me = user.copyWith(messages: const []);
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await api.signOut();
    } catch (_) {
      // Signing out locally still works when the server can't be reached.
    }
    await auth.signOut();
    await _signedOutLocally();
  }

  Future<void> deleteAccount() async {
    await _guard(api.deleteAccount);
    await auth.signOut();
    await _signedOutLocally();
  }

  // ---- Kayra Plus ----

  Future<void> loadPlans() async {
    try {
      plans = await billing.loadPlans();
    } catch (_) {
      plans = const [];
    }
    notifyListeners();
  }

  Future<void> buy(Plan plan) async {
    if (me == null) return;
    buying = true;
    purchaseNotice = null;
    notifyListeners();
    try {
      await billing.buy(plan, accountId: user.purchaseAccountId);
    } catch (_) {
      buying = false;
      purchaseNotice = 'Payment shuru nahi ho paya. Thodi der me phir try karo.';
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    if (me == null) return;
    try {
      await billing.restore(accountId: user.purchaseAccountId);
    } catch (_) {
      // Nothing to restore, or the store is unavailable.
    }
  }

  Future<void> _onPurchase(PurchaseUpdate update) async {
    switch (update.kind) {
      case PurchaseUpdateKind.pending:
        purchaseNotice = 'Payment pending hai. Poora hote hi Kayra Plus chalu ho jayega.';
      case PurchaseUpdateKind.canceled:
        buying = false;
      case PurchaseUpdateKind.failed:
        buying = false;
        purchaseNotice = 'Payment nahi ho paya. Paise kate hon to Google Play apne aap wapas kar dega.';
      case PurchaseUpdateKind.purchased:
        if (me == null) return;
        try {
          final updated = await _guard(
            () => api.verifyPurchase(productId: update.productId, purchaseToken: update.purchaseToken),
          );
          // Only tell the store the purchase is done once our server has recorded it.
          await billing.finish(update);
          final wasActive = user.plus.active;
          _setMe(updated);
          if (updated.plus.active && !wasActive) purchaseNotice = 'Welcome to Kayra Plus 💖';
        } on SignedOut {
          return;
        } catch (_) {
          purchaseNotice = 'Payment ho gaya, par abhi check nahi ho paya. App dobara kholne par Plus chalu ho jayega.';
        }
        buying = false;
    }
    notifyListeners();
  }
}
