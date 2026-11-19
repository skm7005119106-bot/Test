import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---- Google sign-in ----

/// The OAuth *Web* client id from Google Cloud. Set it when building:
/// `--dart-define=GOOGLE_SERVER_CLIENT_ID=1234-abc.apps.googleusercontent.com`
const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class SignInFailed implements Exception {
  const SignInFailed(this.reason);
  final String reason;
}

abstract class AuthService {
  /// A Google ID token, or null when the user closed the account picker.
  Future<String?> signIn();
  Future<void> signOut();
}

class GoogleAuthService implements AuthService {
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: googleServerClientId.isEmpty ? null : googleServerClientId,
    );
    _ready = true;
  }

  @override
  Future<String?> signIn() async {
    try {
      await _init();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const SignInFailed('no_id_token');
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw SignInFailed(e.code.name);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _init();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Signing out of Google is best effort; the app session is already gone.
    }
  }
}

// ---- Google Play Billing ----

class Plan {
  const Plan({required this.id, required this.price, required this.yearly, this.details});

  final String id;
  final String price;
  final bool yearly;

  /// The store's product, needed to buy it.
  final Object? details;
}

enum PurchaseUpdateKind { purchased, pending, failed, canceled }

class PurchaseUpdate {
  const PurchaseUpdate(this.kind, {this.productId = '', this.purchaseToken = '', this.handle});

  final PurchaseUpdateKind kind;
  final String productId;
  final String purchaseToken;

  /// Passed back to [BillingService.finish] once the server has checked the purchase.
  final Object? handle;
}

abstract class BillingService {
  Stream<PurchaseUpdate> get updates;

  /// The Kayra Plus plans from the store, monthly first. Empty when the store is unavailable.
  Future<List<Plan>> loadPlans();
  Future<void> buy(Plan plan, {required String accountId});
  Future<void> restore({required String accountId});
  Future<void> finish(PurchaseUpdate update);
}

class PlayBillingService implements BillingService {
  PlayBillingService() {
    _subscription = _store.purchaseStream.listen(_onPurchases, onError: (_) {});
  }

  static const monthly = 'kayra_plus_monthly';
  static const yearly = 'kayra_plus_yearly';

  final _store = InAppPurchase.instance;
  final _updates = StreamController<PurchaseUpdate>.broadcast();
  // ignore: unused_field
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  @override
  Stream<PurchaseUpdate> get updates => _updates.stream;

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _updates.add(PurchaseUpdate(
            PurchaseUpdateKind.purchased,
            productId: p.productID,
            purchaseToken: p.verificationData.serverVerificationData,
            handle: p,
          ));
        case PurchaseStatus.pending:
          _updates.add(PurchaseUpdate(PurchaseUpdateKind.pending, productId: p.productID));
        case PurchaseStatus.error:
          _updates.add(PurchaseUpdate(PurchaseUpdateKind.failed, productId: p.productID, handle: p));
          if (p.pendingCompletePurchase) _store.completePurchase(p);
        case PurchaseStatus.canceled:
          _updates.add(PurchaseUpdate(PurchaseUpdateKind.canceled, productId: p.productID, handle: p));
          if (p.pendingCompletePurchase) _store.completePurchase(p);
      }
    }
  }

  @override
  Future<List<Plan>> loadPlans() async {
    if (!await _store.isAvailable()) return [];
    final response = await _store.queryProductDetails({monthly, yearly});
    final byId = <String, ProductDetails>{};
    for (final product in response.productDetails) {
      byId.putIfAbsent(product.id, () => product);
    }
    return [
      for (final id in [monthly, yearly])
        if (byId[id] != null) Plan(id: id, price: byId[id]!.price, yearly: id == yearly, details: byId[id]),
    ];
  }

  @override
  Future<void> buy(Plan plan, {required String accountId}) async {
    await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: plan.details! as ProductDetails,
        applicationUserName: accountId,
      ),
    );
  }

  @override
  Future<void> restore({required String accountId}) async {
    if (!await _store.isAvailable()) return;
    await _store.restorePurchases(applicationUserName: accountId);
  }

  @override
  Future<void> finish(PurchaseUpdate update) async {
    final purchase = update.handle;
    if (purchase is PurchaseDetails && purchase.pendingCompletePurchase) {
      await _store.completePurchase(purchase);
    }
  }
}

/// Used where Google Play Billing does not exist (the web build).
class NoBillingService implements BillingService {
  @override
  Stream<PurchaseUpdate> get updates => const Stream.empty();

  @override
  Future<List<Plan>> loadPlans() async => const [];

  @override
  Future<void> buy(Plan plan, {required String accountId}) async {}

  @override
  Future<void> restore({required String accountId}) async {}

  @override
  Future<void> finish(PurchaseUpdate update) async {}
}

// ---- Session token ----

class SessionStore {
  SessionStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<SessionStore> open() async => SessionStore(await SharedPreferences.getInstance());

  String? get token => _prefs.getString('session');
  Future<void> save(String token) => _prefs.setString('session', token);
  Future<void> clear() => _prefs.remove('session');
}
