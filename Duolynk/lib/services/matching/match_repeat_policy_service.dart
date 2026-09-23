import '../../models/match_model.dart';
import 'match_lifecycle_service.dart';

class MatchRepeatPolicyService {
  const MatchRepeatPolicyService();

  DateTime? eligibleForReintroductionAt(MatchModel match) {
    if (match.status == MatchStatus.passed) {
      return match.eligibleForReintroductionAt ??
          (match.passedAt ?? match.createdAt).add(
            MatchLifecycleService.passCooldown,
          );
    }

    if (match.status == MatchStatus.expired) {
      if (match.closureReason == MatchClosureReason.userPaused) {
        return match.eligibleForReintroductionAt ??
            (match.expiredAt ?? match.createdAt).add(
              MatchLifecycleService.pausedClosureCooldown,
            );
      }
      return match.eligibleForReintroductionAt ??
          (match.expiredAt ?? match.expiresAt).add(
            _hasAnyInterest(match)
                ? MatchLifecycleService.expiredWithInterestCooldown
                : MatchLifecycleService.expiredNoInterestCooldown,
          );
    }

    return match.eligibleForReintroductionAt;
  }

  bool excludesFromRecommendations(MatchModel match, DateTime now) {
    if (match.status == MatchStatus.unmatched ||
        match.status == MatchStatus.blocked ||
        match.status == MatchStatus.archived) {
      return true;
    }

    if (match.status == MatchStatus.suggested ||
        match.status == MatchStatus.interested ||
        match.status == MatchStatus.mutual ||
        match.status == MatchStatus.active ||
        match.isConversationEligible) {
      return true;
    }

    if (match.status == MatchStatus.passed ||
        match.status == MatchStatus.expired) {
      final reintroductionAt = eligibleForReintroductionAt(match);
      return reintroductionAt == null || now.isBefore(reintroductionAt);
    }

    return false;
  }

  DateTime passReintroductionAt(DateTime passedAt) {
    return passedAt.add(MatchLifecycleService.passCooldown);
  }

  DateTime expiredReintroductionAt(MatchModel match, DateTime expiredAt) {
    if (match.closureReason == MatchClosureReason.userPaused) {
      return expiredAt.add(MatchLifecycleService.pausedClosureCooldown);
    }
    return expiredAt.add(
      _hasAnyInterest(match)
          ? MatchLifecycleService.expiredWithInterestCooldown
          : MatchLifecycleService.expiredNoInterestCooldown,
    );
  }

  DateTime pausedClosureReintroductionAt(DateTime closedAt) {
    return closedAt.add(MatchLifecycleService.pausedClosureCooldown);
  }

  bool _hasAnyInterest(MatchModel match) {
    return match.participantDecisions.values.any(
      (decision) => decision == MatchParticipantDecision.interested,
    );
  }
}
