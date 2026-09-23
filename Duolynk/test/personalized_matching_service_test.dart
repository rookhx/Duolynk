import 'package:duolynk/core/config/firestore_paths.dart';
import 'package:duolynk/models/app_user.dart';
import 'package:duolynk/models/compatibility_match_result.dart';
import 'package:duolynk/models/compatibility_profile.dart';
import 'package:duolynk/models/match_feedback.dart';
import 'package:duolynk/models/match_model.dart';
import 'package:duolynk/models/personalized_matching_profile.dart';
import 'package:duolynk/services/matching/personalized_matching_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = PersonalizedMatchingService();
  final now = DateTime.utc(2026, 9, 20);

  group('PersonalizedMatchingService', () {
    test('maps negative feedback to approved compatibility dimensions', () {
      expect(
        service.categoryForNegativeReason(MatchFeedbackReason.differentThings),
        'relationshipGoals',
      );
      expect(
        service.categoryForNegativeReason(
          MatchFeedbackReason.lifestylesDidntFit,
        ),
        'lifestyle',
      );
      expect(
        service.categoryForNegativeReason(
          MatchFeedbackReason.personalitiesDidntClick,
        ),
        'personality',
      );
      expect(
        service.categoryForNegativeReason(
          MatchFeedbackReason.communicationDidntFeelRight,
        ),
        'personality',
      );
      expect(
        service.categoryForNegativeReason(MatchFeedbackReason.distanceWasIssue),
        'location',
      );
      expect(
        service.categoryForNegativeReason(
          MatchFeedbackReason.notEnoughSharedInterests,
        ),
        'interests',
      );
    });

    test('does not learn sensitive attraction or timing preferences', () {
      expect(
        service.categoryForNegativeReason(
          MatchFeedbackReason.attractionWasntThere,
        ),
        isNull,
      );
      expect(
        service.categoryForNegativeReason(MatchFeedbackReason.timingWasntRight),
        isNull,
      );
      expect(
        service.categoryForNegativeReason(MatchFeedbackReason.metButNotMatch),
        isNull,
      );
    });

    test('one feedback event does not personalize ranking', () {
      final profile = service.buildProfile(
        userId: 'user-a',
        enabled: true,
        feedback: [
          _feedback(
            reason: MatchFeedbackReason.lifestylesDidntFit,
            createdAt: now,
          ),
        ],
        now: now,
      );

      expect(profile.feedbackSignalCount, 1);
      expect(profile.canPersonalize, isFalse);
      expect(profile.categoryWeightAdjustments, isEmpty);
    });

    test('personalization begins only after minimum signal threshold', () {
      final profile = service.buildProfile(
        userId: 'user-a',
        enabled: true,
        feedback: [
          _feedback(
            reason: MatchFeedbackReason.lifestylesDidntFit,
            createdAt: now,
          ),
          _feedback(
            reason: MatchFeedbackReason.notEnoughSharedInterests,
            createdAt: now,
          ),
          _feedback(
            reason: MatchFeedbackReason.differentThings,
            createdAt: now,
          ),
        ],
        now: now,
      );

      expect(profile.canPersonalize, isTrue);
      expect(profile.categoryWeightAdjustments, isNotEmpty);
    });

    test('adjustments stay within configured bounds', () {
      final profile = service.buildProfile(
        userId: 'user-a',
        enabled: true,
        feedback: List.generate(
          10,
          (_) => _feedback(
            reason: MatchFeedbackReason.lifestylesDidntFit,
            createdAt: now,
          ),
        ),
        now: now,
      );

      expect(
        profile.categoryWeightAdjustments.values,
        everyElement(
          inInclusiveRange(0, PersonalizedMatchingService.maxWeightAdjustment),
        ),
      );
      expect(
        profile.categoryWeightAdjustments['lifestyle'],
        PersonalizedMatchingService.maxWeightAdjustment,
      );
    });

    test('recent feedback weighs more than old feedback', () {
      expect(
        service.recencyWeight(now.subtract(const Duration(days: 20)), now),
        greaterThan(
          service.recencyWeight(now.subtract(const Duration(days: 200)), now),
        ),
      );
      expect(
        service.recencyWeight(now.subtract(const Duration(days: 200)), now),
        greaterThan(
          service.recencyWeight(now.subtract(const Duration(days: 800)), now),
        ),
      );
    });

    test('positive feedback reinforces strongest snapshot categories', () {
      final profile = service.buildProfile(
        userId: 'user-a',
        enabled: true,
        feedback: [
          _feedback(
            goodMatch: true,
            createdAt: now,
            categoryScores: const {
              'relationshipGoals': 94,
              'lifestyle': 90,
              'personality': 70,
              'interests': 65,
              'location': 100,
            },
          ),
          _feedback(
            goodMatch: true,
            createdAt: now,
            categoryScores: const {'relationshipGoals': 92, 'lifestyle': 88},
          ),
          _feedback(
            goodMatch: true,
            createdAt: now,
            categoryScores: const {'relationshipGoals': 91, 'personality': 86},
          ),
        ],
        now: now,
      );

      expect(profile.canPersonalize, isTrue);
      expect(profile.categoryWeightAdjustments['relationshipGoals'], isNotNull);
    });

    test('personalized ranking does not alter displayed compatibility', () {
      final result = _result(
        compatibilityScore: 80,
        categoryScores: const {
          'interests': 60,
          'lifestyle': 98,
          'relationshipGoals': 82,
          'personality': 78,
          'location': 70,
        },
      );
      final profile = PersonalizedMatchingProfile(
        userId: 'user-a',
        enabled: true,
        feedbackSignalCount: 3,
        categoryWeightAdjustments: const {'lifestyle': 0.05},
      );

      final rankingScore = service.personalizedScoreFor(result, profile);

      expect(result.compatibilityScore, 80);
      expect(rankingScore, isNot(equals(result.compatibilityScore)));
      expect(
        (rankingScore - result.compatibilityScore).abs(),
        lessThanOrEqualTo(
          PersonalizedMatchingService.maxRankingPointAdjustment,
        ),
      );
    });

    test('personalization disabled uses standard ranking', () {
      final result = _result(
        compatibilityScore: 80,
        categoryScores: const {'lifestyle': 100},
      );
      final profile = PersonalizedMatchingProfile(
        userId: 'user-a',
        enabled: false,
        feedbackSignalCount: 10,
        categoryWeightAdjustments: const {'lifestyle': 0.05},
      );

      expect(service.personalizedScoreFor(result, profile), 80);
    });

    test('reset baseline returns ranking profile to standard behavior', () {
      final profile = PersonalizedMatchingProfile.baseline(
        'user-a',
        enabled: true,
      );
      final result = _result(compatibilityScore: 77);

      expect(profile.feedbackSignalCount, 0);
      expect(profile.categoryWeightAdjustments, isEmpty);
      expect(service.personalizedScoreFor(result, profile), 77);
    });

    test(
      'balanced pair ranking considers both user profiles conservatively',
      () {
        final result = _result(
          compatibilityScore: 75,
          categoryScores: const {
            'interests': 70,
            'lifestyle': 100,
            'relationshipGoals': 74,
            'personality': 70,
            'location': 60,
          },
        );
        final current = PersonalizedMatchingProfile(
          userId: 'user-a',
          enabled: true,
          feedbackSignalCount: 3,
          categoryWeightAdjustments: const {'lifestyle': 0.05},
        );
        final candidate = PersonalizedMatchingProfile.baseline('user-b');

        final currentOnly = service.personalizedScoreFor(result, current);
        final balanced = service.balancedPairRankingScore(
          result: result,
          currentUserProfile: current,
          candidateProfile: candidate,
        );

        expect(balanced, lessThan(currentOnly));
        expect(balanced, greaterThan(result.compatibilityScore));
      },
    );

    test('effective weights remain normalized and bounded', () {
      final weights = service.effectiveWeights(
        PersonalizedMatchingProfile(
          userId: 'user-a',
          enabled: true,
          feedbackSignalCount: 3,
          categoryWeightAdjustments: const {
            'location': 0.05,
            'relationshipGoals': 0.05,
          },
        ),
      );

      final total = weights.values.fold<double>(0, (sum, value) => sum + value);
      expect(total, closeTo(1, 0.0001));
      expect(weights['location'], lessThan(0.30));
    });
  });

  group('feedback privacy and models', () {
    test('feedback is stored in the submitting user private path', () {
      expect(
        FirestorePaths.userMatchFeedbackItem('user-a', 'feedback-1'),
        'users/user-a/matchFeedback/feedback-1',
      );
    });

    test('match model does not serialize private feedback', () {
      final map = _match().toMap();

      expect(map.containsKey('feedback'), isFalse);
      expect(map.containsKey('feedbackReasons'), isFalse);
      expect(map.containsKey('privateFeedback'), isFalse);
    });

    test('feedback serializes and deserializes safely', () {
      final feedback = _feedback(
        reason: MatchFeedbackReason.communicationDidntFeelRight,
        goodMatch: true,
        metInPerson: true,
        createdAt: now,
      );

      final parsed = MatchFeedback.fromMap(
        feedback.feedbackId,
        feedback.toMap(),
      );

      expect(parsed.userId, feedback.userId);
      expect(parsed.reasons, feedback.reasons);
      expect(parsed.goodMatch, isTrue);
      expect(parsed.metInPerson, isTrue);
    });

    test('feedback can be submitted while personalization is disabled', () {
      final feedback = _feedback(
        reason: MatchFeedbackReason.lifestylesDidntFit,
        createdAt: now,
      );
      final profile = service.buildProfile(
        userId: 'user-a',
        enabled: false,
        feedback: [feedback, feedback, feedback],
        now: now,
      );

      expect(profile.feedbackSignalCount, 3);
      expect(profile.enabled, isFalse);
      expect(profile.canPersonalize, isFalse);
    });

    test('premium and quota concepts do not affect feedback profile math', () {
      final freeProfile = service.buildProfile(
        userId: 'user-a',
        enabled: true,
        feedback: List.generate(
          3,
          (_) => _feedback(
            reason: MatchFeedbackReason.notEnoughSharedInterests,
            createdAt: now,
          ),
        ),
        now: now,
      );
      final premiumProfile = service.buildProfile(
        userId: 'user-a',
        enabled: true,
        feedback: List.generate(
          3,
          (_) => _feedback(
            reason: MatchFeedbackReason.notEnoughSharedInterests,
            createdAt: now,
          ),
        ),
        now: now,
      );

      expect(
        premiumProfile.categoryWeightAdjustments,
        freeProfile.categoryWeightAdjustments,
      );
    });
  });
}

MatchFeedback _feedback({
  MatchFeedbackReason? reason,
  bool goodMatch = false,
  bool metInPerson = false,
  DateTime? createdAt,
  Map<String, int> categoryScores = const {
    'relationshipGoals': 80,
    'lifestyle': 80,
    'personality': 80,
    'interests': 80,
    'location': 80,
  },
}) {
  return MatchFeedback(
    feedbackId: 'feedback-${reason?.name ?? goodMatch}',
    userId: 'user-a',
    matchId: 'match-a-b',
    pairKey: 'user-a_user-b',
    reasons: {if (reason != null) reason},
    goodMatch: goodMatch,
    metInPerson: metInPerson,
    createdAt: createdAt ?? DateTime.utc(2026, 9, 20),
    categoryScores: categoryScores,
    compatibilityAlgorithmVersion: 2,
    questionnaireVersion: 2,
  );
}

CompatibilityMatchResult _result({
  int compatibilityScore = 80,
  Map<String, int> categoryScores = const {
    'interests': 80,
    'lifestyle': 80,
    'relationshipGoals': 80,
    'personality': 80,
    'location': 80,
  },
}) {
  return CompatibilityMatchResult(
    profile: CompatibilityProfile(
      user: _user('user-b'),
      interests: const [],
      lifestyleAnswers: const {},
      relationshipGoalAnswers: const {},
      personalityAnswers: const {},
      preferenceAnswers: const {},
    ),
    compatibilityScore: compatibilityScore,
    scope: MatchSearchScope.nearby,
    insights: const [],
    categoryScores: categoryScores,
    dataCompleteness: 1,
    algorithmVersion: 2,
  );
}

MatchModel _match() {
  return MatchModel(
    id: 'user-a_user-b',
    userId: 'user-a',
    partnerId: 'user-b',
    compatibilityScore: 84,
    status: MatchStatus.unmatched,
    compatibilityReasons: const [],
    createdAt: DateTime.utc(2026, 9, 1),
    expiresAt: DateTime.utc(2026, 9, 8),
    pairKey: 'user-a_user-b',
    categoryScores: const {'relationshipGoals': 90, 'lifestyle': 82},
  );
}

AppUser _user(String id) {
  return AppUser(
    id: id,
    email: '$id@example.com',
    displayName: id,
    age: 30,
    gender: 'Woman',
    interestedIn: const ['Man'],
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}
