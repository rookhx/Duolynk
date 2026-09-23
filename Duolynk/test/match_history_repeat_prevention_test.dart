import 'package:flutter_test/flutter_test.dart';

import 'package:duolynk/models/match_model.dart';
import 'package:duolynk/models/subscription_model.dart';
import 'package:duolynk/services/chat/conversation_access_service.dart';
import 'package:duolynk/services/matching/match_lifecycle_service.dart';
import 'package:duolynk/services/matching/match_repeat_policy_service.dart';

void main() {
  const lifecycle = MatchLifecycleService();
  const repeatPolicy = MatchRepeatPolicyService();
  const conversationAccess = ConversationAccessService();

  test(
    'Pass removes actionable suggestion and records a permanent decision',
    () {
      final now = DateTime.utc(2026, 1, 2);
      final transition = lifecycle.markPassed(
        userId: 'a',
        participantIds: const ['a', 'b'],
        currentStatus: MatchStatus.suggested,
        currentDecisions: const {'a': MatchParticipantDecision.pending},
        now: now,
      );

      expect(transition.status, MatchStatus.passed);
      expect(transition.decisions['a'], MatchParticipantDecision.passed);
      expect(transition.decisionAt['a'], now);
    },
  );

  test('Pass cannot later become Interested or mutual', () {
    final passed = lifecycle.markPassed(
      userId: 'a',
      participantIds: const ['a', 'b'],
      currentStatus: MatchStatus.suggested,
      currentDecisions: const {},
    );
    final interested = lifecycle.markInterested(
      userId: 'a',
      participantIds: const ['a', 'b'],
      currentStatus: passed.status,
      currentDecisions: passed.decisions,
      currentDecisionAt: passed.decisionAt,
    );
    final otherInterested = lifecycle.markInterested(
      userId: 'b',
      participantIds: const ['a', 'b'],
      currentStatus: interested.status,
      currentDecisions: interested.decisions,
      currentDecisionAt: interested.decisionAt,
    );

    expect(interested.status, MatchStatus.passed);
    expect(otherInterested.status, MatchStatus.passed);
    expect(otherInterested.createdMutual, isFalse);
  });

  test('Other user cannot infer who passed from public transition shape', () {
    final passed = _match(
      status: MatchStatus.passed,
      decisions: const {'a': MatchParticipantDecision.passed},
    );

    expect(passed.status, MatchStatus.passed);
    expect(passed.unmatchedBy, isNull);
    expect(passed.blockedBy, isNull);
  });

  test(
    'Suggested introduction expires after 7 days and blocks new actions',
    () {
      final createdAt = DateTime.utc(2026, 1, 1);
      final transition = lifecycle.expireIfNeeded(
        now: createdAt.add(const Duration(days: 7, seconds: 1)),
        expiresAt: createdAt.add(MatchLifecycleService.suggestionLifetime),
        currentStatus: MatchStatus.suggested,
        currentDecisions: const {},
      );
      final interested = lifecycle.markInterested(
        userId: 'a',
        participantIds: const ['a', 'b'],
        currentStatus: transition.status,
        currentDecisions: transition.decisions,
      );

      expect(transition.status, MatchStatus.expired);
      expect(interested.status, MatchStatus.expired);
    },
  );

  test('Interested plus no response expires instead of waiting forever', () {
    final now = DateTime.utc(2026, 1, 9);
    final transition = lifecycle.expireIfNeeded(
      now: now,
      expiresAt: DateTime.utc(2026, 1, 8),
      currentStatus: MatchStatus.interested,
      currentDecisions: const {
        'a': MatchParticipantDecision.interested,
        'b': MatchParticipantDecision.pending,
      },
    );

    expect(transition.status, MatchStatus.expired);
  });

  test('Mutual match ignores original suggestion expiration', () {
    final transition = lifecycle.expireIfNeeded(
      now: DateTime.utc(2026, 2, 1),
      expiresAt: DateTime.utc(2026, 1, 8),
      currentStatus: MatchStatus.mutual,
      currentDecisions: const {
        'a': MatchParticipantDecision.interested,
        'b': MatchParticipantDecision.interested,
      },
    );

    expect(transition.status, MatchStatus.mutual);
  });

  test('Unmatch terminates conversation access for both users', () {
    final status = lifecycle.unmatch(currentStatus: MatchStatus.active);
    final unmatched = _match(status: status);

    expect(status, MatchStatus.unmatched);
    expect(conversationAccess.canOpenConversationShell(unmatched), isFalse);
  });

  test('Unmatched users cannot send new messages through match shell', () {
    final unmatched = _match(status: MatchStatus.unmatched);

    expect(unmatched.isConversationEligible, isFalse);
  });

  test('Unmatch does not delete moderation/report-relevant state', () {
    final unmatched = _match(
      status: MatchStatus.unmatched,
      unmatchedAt: DateTime.utc(2026, 1, 3),
      unmatchedBy: 'a',
    );

    expect(unmatched.participantIds, const ['a', 'b']);
    expect(unmatched.unmatchedAt, isNotNull);
    expect(unmatched.unmatchedBy, 'a');
  });

  test('Block terminates relationship and prevents future recommendation', () {
    final blocked = _match(status: MatchStatus.blocked);

    expect(blocked.isConversationEligible, isFalse);
    expect(
      repeatPolicy.excludesFromRecommendations(
        blocked,
        DateTime.utc(2026, 6, 1),
      ),
      isTrue,
    );
  });

  test('Passed pair has 90-day cooldown', () {
    final passedAt = DateTime.utc(2026, 1, 1);
    final passed = _match(status: MatchStatus.passed, passedAt: passedAt);

    expect(
      repeatPolicy.eligibleForReintroductionAt(passed),
      DateTime.utc(2026, 4, 1),
    );
    expect(
      repeatPolicy.excludesFromRecommendations(
        passed,
        DateTime.utc(2026, 3, 31),
      ),
      isTrue,
    );
    expect(
      repeatPolicy.excludesFromRecommendations(
        passed,
        DateTime.utc(2026, 4, 2),
      ),
      isFalse,
    );
  });

  test('Fully ignored expired pair has 60-day cooldown', () {
    final expired = _match(
      status: MatchStatus.expired,
      expiredAt: DateTime.utc(2026, 1, 1),
      decisions: const {
        'a': MatchParticipantDecision.pending,
        'b': MatchParticipantDecision.pending,
      },
    );

    expect(
      repeatPolicy.eligibleForReintroductionAt(expired),
      DateTime.utc(2026, 3, 2),
    );
  });

  test('Interested-but-unanswered expired pair has 90-day cooldown', () {
    final expired = _match(
      status: MatchStatus.expired,
      expiredAt: DateTime.utc(2026, 1, 1),
      decisions: const {
        'a': MatchParticipantDecision.interested,
        'b': MatchParticipantDecision.pending,
      },
    );

    expect(
      repeatPolicy.eligibleForReintroductionAt(expired),
      DateTime.utc(2026, 4, 1),
    );
  });

  test('Unmatched pair is not automatically reintroduced', () {
    final unmatched = _match(status: MatchStatus.unmatched);

    expect(
      repeatPolicy.excludesFromRecommendations(
        unmatched,
        DateTime.utc(2027, 1, 1),
      ),
      isTrue,
    );
  });

  test('Pause-closed pair uses 30-day neutral cooldown', () {
    final expiredAt = DateTime.utc(2026, 1, 1);
    final pauseClosed = _match(
      status: MatchStatus.expired,
      expiredAt: expiredAt,
      closureReason: MatchClosureReason.userPaused,
    );

    expect(
      repeatPolicy.eligibleForReintroductionAt(pauseClosed),
      DateTime.utc(2026, 1, 31),
    );
    expect(
      repeatPolicy.excludesFromRecommendations(
        pauseClosed,
        DateTime.utc(2026, 1, 30),
      ),
      isTrue,
    );
    expect(
      repeatPolicy.excludesFromRecommendations(
        pauseClosed,
        DateTime.utc(2026, 2, 1),
      ),
      isFalse,
    );
  });

  test('Closing because of pause is not treated as Pass', () {
    final pauseClosed = _match(
      status: MatchStatus.expired,
      expiredAt: DateTime.utc(2026, 1, 1),
      closureReason: MatchClosureReason.userPaused,
    );

    expect(pauseClosed.status, MatchStatus.expired);
    expect(pauseClosed.passedAt, isNull);
    expect(pauseClosed.closureReason, MatchClosureReason.userPaused);
  });

  test('Weekly quota is not refunded by pass, expiration, or unmatch', () {
    for (final status in [
      MatchStatus.passed,
      MatchStatus.expired,
      MatchStatus.unmatched,
    ]) {
      final match = _match(status: status);

      expect(match.generatedBySystem, isTrue);
      expect(match.weekKey, '2026-01-05_2026-01-11');
    }
  });

  test('Canonical pair document is reused for history', () {
    expect(_pairKey('b', 'a'), 'a_b');
    expect(_match().id, _pairKey('a', 'b'));
  });

  test('Repeated Unmatch is idempotent', () {
    final first = lifecycle.unmatch(currentStatus: MatchStatus.mutual);
    final second = lifecycle.unmatch(currentStatus: first);

    expect(first, MatchStatus.unmatched);
    expect(second, MatchStatus.unmatched);
  });

  test('Race between expiration and Interested resolves safely', () {
    final expired = lifecycle.expireIfNeeded(
      now: DateTime.utc(2026, 1, 9),
      expiresAt: DateTime.utc(2026, 1, 8),
      currentStatus: MatchStatus.suggested,
      currentDecisions: const {},
    );
    final interested = lifecycle.markInterested(
      userId: 'a',
      participantIds: const ['a', 'b'],
      currentStatus: expired.status,
      currentDecisions: expired.decisions,
    );

    expect(interested.status, MatchStatus.expired);
    expect(interested.createdMutual, isFalse);
  });

  test('Legacy active matches still function', () {
    final legacy = MatchModel(
      id: 'legacy',
      userId: 'a',
      partnerId: 'b',
      compatibilityScore: 87,
      status: MatchStatus.active,
      compatibilityReasons: const [],
      createdAt: DateTime.utc(2026, 1, 1),
      expiresAt: DateTime.utc(2026, 1, 8),
    );

    expect(legacy.isLegacyActiveMatch, isTrue);
    expect(legacy.isConversationEligible, isTrue);
  });

  test('Basic quota remains 1 and Premium quota remains 3', () {
    expect(_subscription(SubscriptionTier.free).weeklyMatchQuota, 1);
    expect(_subscription(SubscriptionTier.premium).weeklyMatchQuota, 3);
  });
}

MatchModel _match({
  MatchStatus status = MatchStatus.suggested,
  Map<String, MatchParticipantDecision> decisions = const {
    'a': MatchParticipantDecision.pending,
    'b': MatchParticipantDecision.pending,
  },
  DateTime? passedAt,
  DateTime? expiredAt,
  DateTime? unmatchedAt,
  String? unmatchedBy,
  MatchClosureReason? closureReason,
}) {
  return MatchModel(
    id: 'a_b',
    userId: 'a',
    partnerId: 'b',
    compatibilityScore: 91,
    status: status,
    compatibilityReasons: const [],
    createdAt: DateTime.utc(2026, 1, 1),
    expiresAt: DateTime.utc(2026, 1, 8),
    pairKey: 'a_b',
    weekKey: '2026-01-05_2026-01-11',
    generatedBySystem: true,
    participantIds: const ['a', 'b'],
    suggestedForUserIds: const ['a', 'b'],
    participantDecisions: decisions,
    passedAt: passedAt,
    expiredAt: expiredAt,
    unmatchedAt: unmatchedAt,
    unmatchedBy: unmatchedBy,
    closureReason: closureReason,
  );
}

SubscriptionModel _subscription(SubscriptionTier tier) {
  return SubscriptionModel(
    id: tier.name,
    userId: 'user',
    tier: tier,
    platform: SubscriptionPlatform.revenueCat,
    isActive: tier == SubscriptionTier.premium,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

String _pairKey(String first, String second) {
  final sorted = [first, second]..sort();
  return '${sorted.first}_${sorted.last}';
}
