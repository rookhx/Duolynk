import '../../models/match_model.dart';
import '../../models/subscription_model.dart';

class WeeklyAccessService {
  const WeeklyAccessService();

  String weekKey(DateTime date) {
    final utc = date.toUtc();
    final normalized = DateTime.utc(utc.year, utc.month, utc.day);
    final start = normalized.subtract(Duration(days: normalized.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return '${start.year}-${_two(start.month)}-${_two(start.day)}_${end.year}-${_two(end.month)}-${_two(end.day)}';
  }

  bool canUseProfileUnlock({
    required SubscriptionModel subscription,
    required int usedThisWeek,
    required bool alreadyUnlocked,
  }) {
    if (alreadyUnlocked) {
      return true;
    }
    if (subscription.canViewAllAuthorizedCandidateProfiles) {
      return true;
    }
    return usedThisWeek < subscription.weeklyProfileUnlockLimit;
  }

  bool canActivateConversation({
    required SubscriptionModel subscription,
    required int usedThisWeek,
    required bool alreadyActivated,
  }) {
    if (alreadyActivated) {
      return true;
    }
    return usedThisWeek < subscription.weeklyConversationActivationLimit;
  }

  bool hasFullProfileAccess({
    required SubscriptionModel subscription,
    required MatchModel match,
    required bool hasPersistentUnlock,
  }) {
    return hasPersistentUnlock ||
        match.isConversationEligible ||
        subscription.canViewAllAuthorizedCandidateProfiles;
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
