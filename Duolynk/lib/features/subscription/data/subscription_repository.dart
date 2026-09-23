import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/config/firestore_paths.dart';
import '../../../core/demo/demo_store.dart';
import '../../../core/providers/app_startup_provider.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/subscription_model.dart';
import '../../../services/analytics/analytics_event_service.dart';
import '../../../services/firebase/firebase_auth_service.dart';
import '../../../services/firebase/firestore_service.dart';
import '../../../services/revenuecat/revenuecat_service.dart';
import '../domain/paywall_plan.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepository(
    firestoreService: ref.watch(firestoreServiceProvider),
    authService: ref.watch(firebaseAuthServiceProvider),
    revenueCatService: ref.watch(revenueCatServiceProvider),
  ),
);

final subscriptionStatusProvider = FutureProvider<SubscriptionModel>(
  (ref) => ref.watch(subscriptionRepositoryProvider).fetchStatus(),
);

class SubscriptionRepository {
  const SubscriptionRepository({
    required FirestoreService firestoreService,
    required FirebaseAuthService authService,
    required RevenueCatService revenueCatService,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _revenueCatService = revenueCatService;

  final FirestoreService _firestoreService;
  final FirebaseAuthService _authService;
  final RevenueCatService _revenueCatService;

  Future<SubscriptionModel> fetchStatus({bool refresh = true}) async {
    if (!AppEnvironment.firebaseEnabled) {
      return DemoStore.subscription;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return _freeStatus('');
    }

    if (refresh) {
      await syncStatus();
    }

    final snapshot = await _firestoreService
        .collection(FirestorePaths.userSubscriptions(userId))
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return _freeStatus(userId);
    }

    final doc = snapshot.docs.first;
    return SubscriptionModel.fromMap(doc.id, doc.data());
  }

  Future<bool> isRevenueCatAvailable() async {
    if (!AppEnvironment.firebaseEnabled) {
      return true;
    }
    return _revenueCatService.initialize();
  }

  Future<List<PaywallPlan>> fetchPlans() async {
    if (!AppEnvironment.firebaseEnabled) {
      return const [
        PaywallPlan(
          id: 'demo_monthly',
          productId: 'duolynk_premium_monthly',
          title: 'Monthly Premium',
          description:
              'A flexible way to view all curated profiles and activate up to three new conversations weekly.',
          priceLabel: '\$19.99',
          billingLabel: 'Billed monthly',
        ),
        PaywallPlan(
          id: 'demo_annual',
          productId: 'duolynk_premium_annual',
          title: 'Annual Premium',
          description:
              'A longer-term Premium plan for full curated-profile access and more weekly conversation activations.',
          priceLabel: '\$119.99',
          billingLabel: 'Billed yearly',
          badge: 'Best Value',
          savingsLabel: 'Best annual rate',
          isAnnual: true,
        ),
      ];
    }

    final offerings = await _revenueCatService.getOfferings();
    final offering = _selectOffering(offerings);
    if (offering == null) {
      return const [];
    }

    final plans =
        offering.availablePackages
            .map(_mapPlan)
            .whereType<PaywallPlan>()
            .toList()
          ..sort((a, b) {
            if (a.isAnnual == b.isAnnual) {
              return a.priceLabel.compareTo(b.priceLabel);
            }
            return a.isAnnual ? -1 : 1;
          });

    return plans;
  }

  Future<SubscriptionModel> purchasePlan(String planId) async {
    if (!AppEnvironment.firebaseEnabled) {
      DemoStore.subscription = SubscriptionModel(
        id: 'demo_subscription',
        userId: DemoStore.user.id,
        tier: SubscriptionTier.premium,
        platform: SubscriptionPlatform.unknown,
        isActive: true,
        createdAt: DateTime.now(),
        entitlementId: 'premium',
        productId: planId,
      );
      return DemoStore.subscription;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      throw StateError('A signed-in user is required to purchase premium.');
    }

    await _revenueCatService.identify(userId);
    final package = await _findPackage(planId);
    if (package == null) {
      throw StateError('The selected subscription plan is unavailable.');
    }

    final customerInfo = await _revenueCatService.purchasePackage(package);
    if (customerInfo == null) {
      throw StateError('RevenueCat purchase flow is unavailable.');
    }

    return _persistCustomerInfo(userId, customerInfo);
  }

  Future<SubscriptionModel> restorePurchases() async {
    if (!AppEnvironment.firebaseEnabled) {
      return DemoStore.subscription;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      throw StateError('A signed-in user is required to restore purchases.');
    }

    await _revenueCatService.identify(userId);
    final customerInfo = await _revenueCatService.restorePurchases();
    if (customerInfo == null) {
      return _freeStatus(userId);
    }

    return _persistCustomerInfo(userId, customerInfo);
  }

  Future<SubscriptionModel> syncStatus() async {
    if (!AppEnvironment.firebaseEnabled) {
      return DemoStore.subscription;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return _freeStatus('');
    }

    final available = await _revenueCatService.identify(userId);
    if (!available) {
      return _readStoredStatus(userId);
    }

    final customerInfo = await _revenueCatService.getCustomerInfo();
    if (customerInfo == null) {
      return _readStoredStatus(userId);
    }

    return _persistCustomerInfo(userId, customerInfo);
  }

  Future<SubscriptionModel> _readStoredStatus(String userId) async {
    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.userSubscription(userId, _subscriptionDocumentId),
    );
    final data = snapshot.data();
    if (data == null) {
      return _freeStatus(userId);
    }
    return SubscriptionModel.fromMap(snapshot.id, data);
  }

  Future<SubscriptionModel> _persistCustomerInfo(
    String userId,
    CustomerInfo customerInfo,
  ) async {
    final previous = await _readStoredStatus(userId);
    final entitlement = customerInfo
        .entitlements
        .active[AppEnvironment.revenueCatPremiumEntitlementId];
    final expiresAt = _parseDate(entitlement?.expirationDate);
    final isActive = entitlement != null;

    final model = SubscriptionModel(
      id: _subscriptionDocumentId,
      userId: userId,
      tier: isActive ? SubscriptionTier.premium : SubscriptionTier.free,
      platform: SubscriptionPlatform.revenueCat,
      isActive: isActive,
      createdAt: DateTime.now().toUtc(),
      entitlementId: entitlement?.identifier,
      expiresAt: expiresAt,
      productId: entitlement?.productIdentifier,
    );

    await _firestoreService.setDocument(
      FirestorePaths.userSubscription(userId, _subscriptionDocumentId),
      model.toMap(),
      merge: false,
    );

    if (previous.hasPremiumAccess && !model.hasPremiumAccess) {
      await const AnalyticsEventService().track('premium_access_lost');
    }

    return model;
  }

  Offering? _selectOffering(Offerings? offerings) {
    if (offerings == null) {
      return null;
    }

    if (AppEnvironment.revenueCatOfferingId.isNotEmpty) {
      final named = offerings.getOffering(AppEnvironment.revenueCatOfferingId);
      if (named != null) {
        return named;
      }
    }

    return offerings.current;
  }

  PaywallPlan? _mapPlan(Package package) {
    final product = package.storeProduct;
    final productId = product.identifier;
    final isAnnual =
        package.packageType == PackageType.annual ||
        productId == AppEnvironment.revenueCatAnnualProductId;
    final isMonthly =
        package.packageType == PackageType.monthly ||
        productId == AppEnvironment.revenueCatMonthlyProductId;

    if (!isAnnual && !isMonthly) {
      return null;
    }

    return PaywallPlan(
      id: package.identifier,
      productId: productId,
      title: isAnnual ? 'Annual Premium' : 'Monthly Premium',
      description: isAnnual
          ? 'A longer-term Premium plan for full curated-profile access and more weekly conversation activations.'
          : 'A flexible way to view all curated profiles and activate up to three new conversations weekly.',
      priceLabel: product.priceString,
      billingLabel: isAnnual ? 'Billed yearly' : 'Billed monthly',
      badge: isAnnual ? 'Best Value' : null,
      savingsLabel: isAnnual ? 'Best annual rate' : null,
      isAnnual: isAnnual,
    );
  }

  Future<Package?> _findPackage(String planId) async {
    final offerings = await _revenueCatService.getOfferings();
    final offering = _selectOffering(offerings);
    if (offering == null) {
      return null;
    }

    for (final package in offering.availablePackages) {
      if (package.identifier == planId) {
        return package;
      }
    }
    return null;
  }

  SubscriptionModel _freeStatus(String userId) {
    return SubscriptionModel(
      id: userId.isEmpty ? 'guest' : _subscriptionDocumentId,
      userId: userId,
      tier: SubscriptionTier.free,
      platform: SubscriptionPlatform.unknown,
      isActive: false,
      createdAt: DateTime.now().toUtc(),
    );
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }

  static const String _subscriptionDocumentId = 'revenuecat_premium';
}
