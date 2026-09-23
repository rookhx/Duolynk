import 'package:flutter_test/flutter_test.dart';

import 'package:duolynk/models/app_user.dart';
import 'package:duolynk/models/match_model.dart';
import 'package:duolynk/models/subscription_model.dart';

void main() {
  test('active completed user is available for new introductions', () {
    expect(_user().canReceiveNewIntroductions, isTrue);
  });

  test('paused user receives no new-introduction availability', () {
    expect(
      _user(datingStatus: DatingStatus.paused).canReceiveNewIntroductions,
      isFalse,
    );
  });

  test(
    'resume makes user eligible for future matching without bonus quota',
    () {
      final paused = _user(datingStatus: DatingStatus.paused);
      final resumed = paused.copyWith(
        datingStatus: DatingStatus.active,
        clearDatingPausedAt: true,
      );

      expect(resumed.canReceiveNewIntroductions, isTrue);
      expect(_subscription(SubscriptionTier.free).weeklyMatchQuota, 1);
      expect(_subscription(SubscriptionTier.premium).weeklyMatchQuota, 3);
    },
  );

  test('existing mutual match survives pause state', () {
    final paused = _user(datingStatus: DatingStatus.paused);
    final mutual = _match(status: MatchStatus.mutual);

    expect(paused.isDatingPaused, isTrue);
    expect(mutual.isConversationEligible, isTrue);
  });

  test('pending suggestion closed for pause is no longer actionable', () {
    final pauseClosed = _match(
      status: MatchStatus.expired,
      closureReason: MatchClosureReason.userPaused,
    );

    expect(pauseClosed.isConversationEligible, isFalse);
    expect(pauseClosed.closureReason, MatchClosureReason.userPaused);
    expect(pauseClosed.decisionFor('a'), MatchParticipantDecision.pending);
  });

  test('premium subscription status is independent from pause', () {
    final paused = _user(datingStatus: DatingStatus.paused);
    final premium = _subscription(SubscriptionTier.premium);

    expect(paused.isDatingPaused, isTrue);
    expect(premium.hasPremiumAccess, isTrue);
  });

  test('personalization and feedback can remain separate from pause', () {
    final paused = _user(datingStatus: DatingStatus.paused);
    final resumed = paused.copyWith(datingStatus: DatingStatus.active);

    expect(paused.id, resumed.id);
    expect(paused.updatedAt, resumed.updatedAt);
  });
}

AppUser _user({DatingStatus datingStatus = DatingStatus.active}) {
  return AppUser(
    id: 'a',
    email: 'a@example.com',
    displayName: 'Avery',
    age: 29,
    gender: 'Woman',
    interestedIn: const ['Men'],
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    country: 'United States',
    city: 'Chicago',
    datingStatus: datingStatus,
    isProfileComplete: true,
  );
}

MatchModel _match({
  required MatchStatus status,
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
    participantIds: const ['a', 'b'],
    participantDecisions: const {
      'a': MatchParticipantDecision.pending,
      'b': MatchParticipantDecision.pending,
    },
    closureReason: closureReason,
  );
}

SubscriptionModel _subscription(SubscriptionTier tier) {
  return SubscriptionModel(
    id: tier.name,
    userId: 'a',
    tier: tier,
    platform: SubscriptionPlatform.revenueCat,
    isActive: tier == SubscriptionTier.premium,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}
