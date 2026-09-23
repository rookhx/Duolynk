import '../../models/match_model.dart';

class MatchLifecycleTransition {
  const MatchLifecycleTransition({
    required this.status,
    required this.decisions,
    this.decisionAt = const {},
    this.createdMutual = false,
  });

  final MatchStatus status;
  final Map<String, MatchParticipantDecision> decisions;
  final Map<String, DateTime> decisionAt;
  final bool createdMutual;
}

class MatchLifecycleService {
  const MatchLifecycleService();

  static const suggestionLifetime = Duration(days: 7);
  static const passCooldown = Duration(days: 90);
  static const expiredNoInterestCooldown = Duration(days: 60);
  static const expiredWithInterestCooldown = Duration(days: 90);
  static const pausedClosureCooldown = Duration(days: 30);

  MatchLifecycleTransition markInterested({
    required String userId,
    required List<String> participantIds,
    required MatchStatus currentStatus,
    required Map<String, MatchParticipantDecision> currentDecisions,
    Map<String, DateTime> currentDecisionAt = const {},
    DateTime? now,
  }) {
    if (_isTerminalForSuggestionActions(currentStatus)) {
      return MatchLifecycleTransition(
        status: currentStatus,
        decisions: currentDecisions,
        decisionAt: currentDecisionAt,
      );
    }

    final existingDecision =
        currentDecisions[userId] ?? MatchParticipantDecision.pending;
    if (existingDecision == MatchParticipantDecision.passed ||
        currentStatus == MatchStatus.passed ||
        currentStatus == MatchStatus.expired) {
      return MatchLifecycleTransition(
        status: currentStatus,
        decisions: currentDecisions,
        decisionAt: currentDecisionAt,
      );
    }

    if (existingDecision == MatchParticipantDecision.interested &&
        currentStatus == MatchStatus.mutual) {
      return MatchLifecycleTransition(
        status: currentStatus,
        decisions: currentDecisions,
        decisionAt: currentDecisionAt,
      );
    }

    final actionTime = now ?? DateTime.now().toUtc();
    final nextDecisions = {
      for (final participantId in participantIds)
        participantId:
            currentDecisions[participantId] ?? MatchParticipantDecision.pending,
      ...currentDecisions,
      userId: MatchParticipantDecision.interested,
    };
    final nextDecisionAt = {
      ...currentDecisionAt,
      userId: currentDecisionAt[userId] ?? actionTime,
    };
    final allInterested = participantIds.every(
      (participantId) =>
          nextDecisions[participantId] == MatchParticipantDecision.interested,
    );
    final nextStatus = allInterested
        ? MatchStatus.mutual
        : MatchStatus.interested;

    return MatchLifecycleTransition(
      status: nextStatus,
      decisions: nextDecisions,
      decisionAt: nextDecisionAt,
      createdMutual: allInterested && currentStatus != MatchStatus.mutual,
    );
  }

  MatchLifecycleTransition markPassed({
    required String userId,
    required List<String> participantIds,
    required MatchStatus currentStatus,
    required Map<String, MatchParticipantDecision> currentDecisions,
    Map<String, DateTime> currentDecisionAt = const {},
    DateTime? now,
  }) {
    if (currentStatus == MatchStatus.mutual ||
        currentStatus == MatchStatus.active ||
        _isTerminalForSuggestionActions(currentStatus)) {
      return MatchLifecycleTransition(
        status: currentStatus,
        decisions: currentDecisions,
        decisionAt: currentDecisionAt,
      );
    }

    final actionTime = now ?? DateTime.now().toUtc();
    return MatchLifecycleTransition(
      status: MatchStatus.passed,
      decisions: {
        for (final participantId in participantIds)
          participantId:
              currentDecisions[participantId] ??
              MatchParticipantDecision.pending,
        ...currentDecisions,
        userId: MatchParticipantDecision.passed,
      },
      decisionAt: {...currentDecisionAt, userId: actionTime},
    );
  }

  MatchLifecycleTransition expireIfNeeded({
    required DateTime now,
    required DateTime expiresAt,
    required MatchStatus currentStatus,
    required Map<String, MatchParticipantDecision> currentDecisions,
    Map<String, DateTime> currentDecisionAt = const {},
  }) {
    if (now.isBefore(expiresAt) ||
        currentStatus == MatchStatus.mutual ||
        currentStatus == MatchStatus.active ||
        currentStatus == MatchStatus.passed ||
        currentStatus == MatchStatus.expired ||
        currentStatus == MatchStatus.unmatched ||
        currentStatus == MatchStatus.blocked ||
        currentStatus == MatchStatus.archived) {
      return MatchLifecycleTransition(
        status: currentStatus,
        decisions: currentDecisions,
        decisionAt: currentDecisionAt,
      );
    }

    return MatchLifecycleTransition(
      status: MatchStatus.expired,
      decisions: currentDecisions,
      decisionAt: currentDecisionAt,
    );
  }

  MatchStatus unmatch({required MatchStatus currentStatus}) {
    if (currentStatus == MatchStatus.unmatched) {
      return currentStatus;
    }
    if (currentStatus == MatchStatus.mutual ||
        currentStatus == MatchStatus.active) {
      return MatchStatus.unmatched;
    }
    return currentStatus;
  }

  bool _isTerminalForSuggestionActions(MatchStatus status) {
    return status == MatchStatus.unmatched ||
        status == MatchStatus.blocked ||
        status == MatchStatus.archived;
  }
}
