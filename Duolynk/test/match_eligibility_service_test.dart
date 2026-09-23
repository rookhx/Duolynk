import 'package:flutter_test/flutter_test.dart';

import 'package:duolynk/models/app_user.dart';
import 'package:duolynk/models/compatibility_profile.dart';
import 'package:duolynk/models/subscription_model.dart';
import 'package:duolynk/services/matching/compatibility_engine_service.dart';
import 'package:duolynk/services/matching/match_eligibility_service.dart';

void main() {
  const service = MatchEligibilityService();

  test('mutually compatible preferences are eligible', () {
    final result = service.evaluate(
      currentUser: _profile(),
      candidate: _profile(
        id: 'candidate',
        age: 30,
        gender: 'Man',
        interestedIn: const ['Women'],
      ),
    );

    expect(result.eligible, isTrue);
    expect(result.rejectionCode, isNull);
  });

  test('wrong interested-in gender is rejected', () {
    final result = service.evaluate(
      currentUser: _profile(interestedIn: const ['Women']),
      candidate: _profile(
        id: 'candidate',
        gender: 'Man',
        interestedIn: const ['Women'],
      ),
    );

    expect(result.eligible, isFalse);
    expect(
      result.rejectionCode,
      MatchEligibilityRejectionCode.genderPreferenceMismatch,
    );
  });

  test('one-sided gender incompatibility is rejected', () {
    final result = service.evaluate(
      currentUser: _profile(),
      candidate: _profile(
        id: 'candidate',
        gender: 'Man',
        interestedIn: const ['Men'],
      ),
    );

    expect(result.eligible, isFalse);
    expect(
      result.rejectionCode,
      MatchEligibilityRejectionCode.genderPreferenceMismatch,
    );
  });

  test('outside age preference is rejected', () {
    final result = service.evaluate(
      currentUser: _profile(preferences: const {'ageRange': '25-35'}),
      candidate: _profile(
        id: 'candidate',
        age: 37,
        gender: 'Man',
        interestedIn: const ['Women'],
      ),
    );

    expect(result.eligible, isFalse);
    expect(
      result.rejectionCode,
      MatchEligibilityRejectionCode.agePreferenceMismatch,
    );
  });

  test('one-sided age incompatibility is rejected', () {
    final result = service.evaluate(
      currentUser: _profile(age: 29),
      candidate: _profile(
        id: 'candidate',
        age: 30,
        gender: 'Man',
        interestedIn: const ['Women'],
        preferences: const {'ageRange': '31-35'},
      ),
    );

    expect(result.eligible, isFalse);
    expect(
      result.rejectionCode,
      MatchEligibilityRejectionCode.agePreferenceMismatch,
    );
  });

  test('distance outside required range is rejected', () {
    final result = service.evaluate(
      currentUser: _profile(
        country: 'United States',
        city: 'Chicago',
        preferences: const {'distancePreference': 'Same City'},
      ),
      candidate: _profile(
        id: 'candidate',
        gender: 'Man',
        interestedIn: const ['Women'],
        country: 'United States',
        city: 'New York',
      ),
    );

    expect(result.eligible, isFalse);
    expect(
      result.rejectionCode,
      MatchEligibilityRejectionCode.distancePreferenceMismatch,
    );
  });

  test('deal breaker conflict is rejected', () {
    final result = service.evaluate(
      currentUser: _profile(
        preferences: const {
          'dealBreakers': ['Smoking'],
        },
      ),
      candidate: _profile(
        id: 'candidate',
        gender: 'Man',
        interestedIn: const ['Women'],
        lifestyle: const {'smoking': 'Regularly'},
      ),
    );

    expect(result.eligible, isFalse);
    expect(
      result.rejectionCode,
      MatchEligibilityRejectionCode.dealBreakerConflict,
    );
  });

  test('incompatible relationship intentions are rejected', () {
    final result = service.evaluate(
      currentUser: _profile(
        relationshipGoals: const {
          'marriage': 'Definitely want it',
          'longTermRelationship': 'Essential',
          'casualDating': 'Not interested',
        },
      ),
      candidate: _profile(
        id: 'candidate',
        gender: 'Man',
        interestedIn: const ['Women'],
        relationshipGoals: const {
          'marriage': 'Do not want it',
          'longTermRelationship': 'Not looking for that',
          'casualDating': 'Prefer casual right now',
        },
      ),
    );

    expect(result.eligible, isFalse);
    expect(
      result.rejectionCode,
      MatchEligibilityRejectionCode.relationshipIntentionMismatch,
    );
  });

  test('blocked user is rejected', () {
    final result = service.evaluate(
      currentUser: _profile(),
      candidate: _profile(
        id: 'candidate',
        gender: 'Man',
        interestedIn: const ['Women'],
      ),
      context: const MatchEligibilityContext(blockedUserIds: {'candidate'}),
    );

    expect(result.eligible, isFalse);
    expect(result.rejectionCode, MatchEligibilityRejectionCode.blockedUser);
  });

  test('existing match is rejected', () {
    final result = service.evaluate(
      currentUser: _profile(),
      candidate: _profile(
        id: 'candidate',
        gender: 'Man',
        interestedIn: const ['Women'],
      ),
      context: const MatchEligibilityContext(activePartnerIds: {'candidate'}),
    );

    expect(result.eligible, isFalse);
    expect(result.rejectionCode, MatchEligibilityRejectionCode.existingMatch);
  });

  test('same user is rejected', () {
    final result = service.evaluate(
      currentUser: _profile(),
      candidate: _profile(),
    );

    expect(result.eligible, isFalse);
    expect(result.rejectionCode, MatchEligibilityRejectionCode.sameUser);
  });

  test('legacy missing preference data is handled without crashing', () {
    final result = service.evaluate(
      currentUser: _profile(
        gender: 'unspecified',
        interestedIn: const [],
        country: null,
        city: null,
        preferences: const {},
      ),
      candidate: _profile(
        id: 'candidate',
        gender: 'Man',
        interestedIn: const [],
        country: null,
        city: null,
        preferences: const {},
      ),
    );

    expect(result.eligible, isTrue);
  });

  test('paused user is excluded before compatibility scoring', () {
    final result = service.evaluate(
      currentUser: _profile(),
      candidate: _profile(
        id: 'candidate',
        gender: 'Man',
        interestedIn: const ['Women'],
        datingStatus: DatingStatus.paused,
      ),
    );

    expect(result.eligible, isFalse);
    expect(
      result.rejectionCode,
      MatchEligibilityRejectionCode.matchingDisabled,
    );
  });

  test('onboarding-incomplete user does not enter matching', () {
    final result = service.evaluate(
      currentUser: _profile(isProfileComplete: false),
      candidate: _profile(
        id: 'candidate',
        gender: 'Man',
        interestedIn: const ['Women'],
      ),
    );

    expect(result.eligible, isFalse);
    expect(
      result.rejectionCode,
      MatchEligibilityRejectionCode.onboardingIncomplete,
    );
  });

  test('legacy active users without pause fields default safely', () {
    final user = AppUser.fromMap('legacy', {
      'email': 'legacy@example.com',
      'displayName': 'Legacy',
      'age': 32,
      'gender': 'Woman',
      'interestedIn': ['Men'],
      'isProfileComplete': true,
    });

    expect(user.datingStatus, DatingStatus.active);
    expect(user.canReceiveNewIntroductions, isTrue);
  });

  test('valid candidate reaches CompatibilityEngineService', () {
    final currentUser = _profile();
    final candidate = _profile(
      id: 'candidate',
      gender: 'Man',
      interestedIn: const ['Women'],
      interests: const ['Travel', 'Music'],
    );

    final eligibility = service.evaluate(
      currentUser: currentUser,
      candidate: candidate,
    );
    final ranked = eligibility.eligible
        ? const CompatibilityEngineService().rankCandidates(
            currentUser: currentUser,
            candidates: [candidate],
          )
        : const [];

    expect(ranked, hasLength(1));
    expect(ranked.single.profile.user.id, 'candidate');
  });

  test('free and premium weekly quota limits remain unchanged', () {
    final free = SubscriptionModel(
      id: 'free',
      userId: 'user',
      tier: SubscriptionTier.free,
      platform: SubscriptionPlatform.unknown,
      isActive: false,
      createdAt: DateTime(2026),
    );
    final premium = SubscriptionModel(
      id: 'premium',
      userId: 'user',
      tier: SubscriptionTier.premium,
      platform: SubscriptionPlatform.revenueCat,
      isActive: true,
      createdAt: DateTime(2026),
    );

    expect(free.weeklyMatchQuota, 1);
    expect(premium.weeklyMatchQuota, 3);
  });
}

CompatibilityProfile _profile({
  String id = 'current',
  int age = 29,
  String gender = 'Woman',
  List<String> interestedIn = const ['Men'],
  String? country = 'United States',
  String? city = 'Chicago',
  List<String> interests = const ['Travel'],
  Map<String, String> lifestyle = const {
    'smoking': 'Never',
    'drinking': 'Socially',
  },
  Map<String, String> relationshipGoals = const {
    'marriage': 'Open to it',
    'longTermRelationship': 'Very important',
    'casualDating': 'Depends on the person',
    'children': 'Open to children',
    'familyImportance': 'Very important',
  },
  Map<String, dynamic> preferences = const {
    'ageRange': '25-35',
    'distancePreference': 'Same Country',
    'dealBreakers': <String>[],
  },
  DatingStatus datingStatus = DatingStatus.active,
  bool isProfileComplete = true,
}) {
  return CompatibilityProfile(
    user: AppUser(
      id: id,
      email: '$id@example.com',
      displayName: id,
      age: age,
      gender: gender,
      interestedIn: interestedIn,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      country: country,
      city: city,
      datingStatus: datingStatus,
      isProfileComplete: isProfileComplete,
    ),
    interests: interests,
    lifestyleAnswers: lifestyle,
    relationshipGoalAnswers: relationshipGoals,
    personalityAnswers: const {},
    preferenceAnswers: preferences,
  );
}
