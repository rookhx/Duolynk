import '../../../models/subscription_model.dart';
import 'paywall_plan.dart';

class SubscriptionState {
  const SubscriptionState({
    required this.status,
    this.plans = const [],
    this.selectedPlanId,
    this.revenueCatReady = false,
    this.isBusy = false,
    this.errorMessage,
  });

  final SubscriptionModel status;
  final List<PaywallPlan> plans;
  final String? selectedPlanId;
  final bool revenueCatReady;
  final bool isBusy;
  final String? errorMessage;

  PaywallPlan? get selectedPlan {
    if (plans.isEmpty) {
      return null;
    }
    if (selectedPlanId != null) {
      for (final plan in plans) {
        if (plan.id == selectedPlanId) {
          return plan;
        }
      }
    }
    return plans.first;
  }

  SubscriptionState copyWith({
    SubscriptionModel? status,
    List<PaywallPlan>? plans,
    String? selectedPlanId,
    bool? revenueCatReady,
    bool? isBusy,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      plans: plans ?? this.plans,
      selectedPlanId: selectedPlanId ?? this.selectedPlanId,
      revenueCatReady: revenueCatReady ?? this.revenueCatReady,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}
