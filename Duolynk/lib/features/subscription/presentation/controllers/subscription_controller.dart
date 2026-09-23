import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/subscription_repository.dart';
import '../../domain/subscription_state.dart';

final subscriptionControllerProvider =
    AsyncNotifierProvider<SubscriptionController, SubscriptionState>(
      SubscriptionController.new,
    );

class SubscriptionController extends AsyncNotifier<SubscriptionState> {
  @override
  Future<SubscriptionState> build() async {
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  void selectPlan(String planId) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(selectedPlanId: planId, clearErrorMessage: true),
    );
  }

  Future<bool> purchaseSelectedPlan() async {
    final current = state.valueOrNull;
    final plan = current?.selectedPlan;
    if (current == null || plan == null) {
      return false;
    }

    state = AsyncData(current.copyWith(isBusy: true, clearErrorMessage: true));
    try {
      final repository = ref.read(subscriptionRepositoryProvider);
      final status = await repository.purchasePlan(plan.id);
      final plans = await repository.fetchPlans();
      state = AsyncData(
        SubscriptionState(
          status: status,
          plans: plans,
          selectedPlanId: plan.id,
          revenueCatReady: await repository.isRevenueCatAvailable(),
        ),
      );
      ref.invalidate(subscriptionStatusProvider);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      state = AsyncData(
        current.copyWith(isBusy: false, errorMessage: error.toString()),
      );
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    final current = state.valueOrNull;
    if (current == null) {
      return false;
    }

    state = AsyncData(current.copyWith(isBusy: true, clearErrorMessage: true));
    try {
      final repository = ref.read(subscriptionRepositoryProvider);
      final status = await repository.restorePurchases();
      final plans = await repository.fetchPlans();
      state = AsyncData(
        SubscriptionState(
          status: status,
          plans: plans,
          selectedPlanId: current.selectedPlanId,
          revenueCatReady: await repository.isRevenueCatAvailable(),
        ),
      );
      ref.invalidate(subscriptionStatusProvider);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      state = AsyncData(
        current.copyWith(isBusy: false, errorMessage: error.toString()),
      );
      return false;
    }
  }

  Future<SubscriptionState> _load() async {
    final repository = ref.read(subscriptionRepositoryProvider);
    final status = await repository.fetchStatus();
    final plans = await repository.fetchPlans();
    final annualPlan = plans.where((plan) => plan.isAnnual).toList();

    return SubscriptionState(
      status: status,
      plans: plans,
      selectedPlanId: annualPlan.isNotEmpty
          ? annualPlan.first.id
          : (plans.isNotEmpty ? plans.first.id : null),
      revenueCatReady: await repository.isRevenueCatAvailable(),
    );
  }
}
