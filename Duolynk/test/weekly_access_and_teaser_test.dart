import 'package:duolynk/models/app_user.dart';
import 'package:duolynk/models/curated_candidate_teaser.dart';
import 'package:duolynk/models/match_model.dart';
import 'package:duolynk/models/subscription_model.dart';
import 'package:duolynk/services/access/weekly_access_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const access = WeeklyAccessService();

  test('Basic and Premium both receive up to 10 curated candidates', () {
    final basic = _subscription(SubscriptionTier.free, false);
    final premium = _subscription(SubscriptionTier.premium, true);

    expect(basic.weeklyCandidateLimit, 10);
    expect(premium.weeklyCandidateLimit, 10);
    expect(basic.hasPriorityMatching, isFalse);
    expect(premium.hasPriorityMatching, isFalse);
  });

  test(
    'Basic gets 1 profile unlock and Premium gets all candidate profiles',
    () {
      final basic = _subscription(SubscriptionTier.free, false);
      final premium = _subscription(SubscriptionTier.premium, true);

      expect(
        access.canUseProfileUnlock(
          subscription: basic,
          usedThisWeek: 0,
          alreadyUnlocked: false,
        ),
        isTrue,
      );
      expect(
        access.canUseProfileUnlock(
          subscription: basic,
          usedThisWeek: 1,
          alreadyUnlocked: false,
        ),
        isFalse,
      );
      expect(
        access.canUseProfileUnlock(
          subscription: premium,
          usedThisWeek: 10,
          alreadyUnlocked: false,
        ),
        isTrue,
      );
    },
  );

  test('Basic gets 1 activation and Premium gets 3 activations weekly', () {
    final basic = _subscription(SubscriptionTier.free, false);
    final premium = _subscription(SubscriptionTier.premium, true);

    expect(basic.weeklyConversationActivationLimit, 1);
    expect(premium.weeklyConversationActivationLimit, 3);
    expect(
      access.canActivateConversation(
        subscription: basic,
        usedThisWeek: 1,
        alreadyActivated: false,
      ),
      isFalse,
    );
    expect(
      access.canActivateConversation(
        subscription: premium,
        usedThisWeek: 2,
        alreadyActivated: false,
      ),
      isTrue,
    );
  });

  test('activated conversation access is persistent after downgrade', () {
    final downgraded = _subscription(SubscriptionTier.free, false);

    expect(
      access.canActivateConversation(
        subscription: downgraded,
        usedThisWeek: 1,
        alreadyActivated: true,
      ),
      isTrue,
    );
  });

  test('curated candidate teaser excludes full private profile content', () {
    final candidate = _candidate();
    final teaser = CuratedCandidateTeaser.fromMatch(
      match: _match(),
      candidate: candidate,
      relationshipIntention: 'Looking for a serious relationship',
    );

    expect(teaser.compatibilityScore, 87);
    expect(teaser.generalLocation, 'Chicago, United States');
    expect(teaser.relationshipIntention, 'Looking for a serious relationship');
    expect(teaser.candidateUserId, candidate.id);
    expect(teaser.isVerified, isTrue);
    expect(teaser, isNot(isA<AppUser>()));
  });

  test('weekly access service uses the same Monday-Sunday week key shape', () {
    expect(access.weekKey(DateTime.utc(2026, 9, 24)), '2026-09-21_2026-09-27');
  });
}

SubscriptionModel _subscription(SubscriptionTier tier, bool active) {
  return SubscriptionModel(
    id: tier.name,
    userId: 'user-a',
    tier: tier,
    platform: SubscriptionPlatform.revenueCat,
    isActive: active,
    createdAt: DateTime.utc(2026),
  );
}

MatchModel _match() {
  return MatchModel(
    id: 'a_b',
    userId: 'a',
    partnerId: 'b',
    compatibilityScore: 87,
    status: MatchStatus.suggested,
    compatibilityReasons: const [],
    createdAt: DateTime.utc(2026),
    expiresAt: DateTime.utc(2026, 9, 29),
    pairKey: 'a_b',
  );
}

AppUser _candidate() {
  return AppUser(
    id: 'b',
    email: 'b@example.com',
    displayName: 'Bea',
    age: 29,
    gender: 'Woman',
    interestedIn: const ['Men'],
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    city: 'Chicago',
    country: 'United States',
    verificationStatus: VerificationStatus.verified,
    bio: 'This should stay out of teaser data.',
    photoUrl: 'https://example.com/private-clear-photo.jpg',
  );
}
