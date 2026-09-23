import 'package:flutter_test/flutter_test.dart';

import 'package:duolynk/models/app_user.dart';
import 'package:duolynk/models/compatibility_insight.dart';
import 'package:duolynk/models/compatibility_profile.dart';
import 'package:duolynk/models/match_model.dart';
import 'package:duolynk/models/subscription_model.dart';
import 'package:duolynk/services/matching/compatibility_engine_service.dart';
import 'package:duolynk/services/matching/compatibility_insight_service.dart';

void main() {
  const engine = CompatibilityEngineService();

  test('overall compatibility percentage remains the engine result', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(),
          candidates: [_profile(id: 'candidate')],
        )
        .single;
    final match = _matchFromResult(result);

    expect(match.compatibilityScore, result.compatibilityScore);
  });

  test('strong relationship alignment creates an appropriate insight', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(),
          candidates: [_profile(id: 'candidate')],
        )
        .single;

    expect(
      result.insights,
      contains(
        isA<CompatibilityInsight>()
            .having(
              (insight) => insight.category,
              'category',
              'relationshipGoals',
            )
            .having(
              (insight) => insight.title,
              'title',
              contains('relationship'),
            ),
      ),
    );
  });

  test('shared interests create an insight using actual overlap', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(
            interests: const ['Travel', 'Cooking', 'Gaming'],
          ),
          candidates: [
            _profile(id: 'candidate', interests: const ['Travel', 'Cooking']),
          ],
        )
        .single;
    final interest = result.insights.firstWhere(
      (insight) => insight.type == 'shared_interests',
    );

    expect(interest.description, contains('Cooking'));
    expect(interest.description, contains('Travel'));
    expect(interest.description, isNot(contains('Gaming')));
  });

  test('large shared-interest lists are truncated and readable', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(
            interests: const [
              'Travel',
              'Cooking',
              'Gaming',
              'Music',
              'Movies',
              'Reading',
              'Fitness',
            ],
          ),
          candidates: [
            _profile(
              id: 'candidate',
              interests: const [
                'Travel',
                'Cooking',
                'Gaming',
                'Music',
                'Movies',
                'Reading',
                'Fitness',
              ],
            ),
          ],
        )
        .single;
    final interest = result.insights.firstWhere(
      (insight) => insight.type == 'shared_interests',
    );

    expect(interest.description, contains('4 more shared interests'));
  });

  test('lifestyle compatibility can create a generalized safe insight', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(),
          candidates: [_profile(id: 'candidate')],
        )
        .single;
    final lifestyle = result.insights.firstWhere(
      (insight) => insight.category == 'lifestyle',
    );

    expect(lifestyle.description, contains('lifestyle preferences'));
    expect(lifestyle.description.toLowerCase(), isNot(contains('drinking')));
    expect(lifestyle.description.toLowerCase(), isNot(contains('smoking')));
  });

  test('personality similarity can create an insight', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(),
          candidates: [_profile(id: 'candidate')],
        )
        .single;

    expect(
      result.insights.any((insight) => insight.category == 'personality'),
      isTrue,
    );
  });

  test('complementary personality rules can produce appropriate wording', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(
            personality: const {
              'communicationStyle': 'Direct and clear',
              'conflictResolution': 'Talk it through quickly',
            },
          ),
          candidates: [
            _profile(
              id: 'candidate',
              personality: const {
                'communicationStyle': 'Warm and reflective',
                'conflictResolution': 'Work toward compromise',
              },
            ),
          ],
        )
        .single;

    expect(
      result.insights.any(
        (insight) =>
            insight.type == 'complementary_personality' &&
            insight.description.contains('different strengths'),
      ),
      isTrue,
    );
  });

  test('location insight never exposes coordinates', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(latitude: 41.8781, longitude: -87.6298),
          candidates: [
            _profile(id: 'candidate', latitude: 41.88, longitude: -87.63),
          ],
        )
        .single;
    final text = result.insights
        .map((insight) => insight.description)
        .join(' ');

    expect(text, isNot(contains('41.')));
    expect(text, isNot(contains('-87.')));
  });

  test(
    'deal breakers and hidden preferences never appear in explanation text',
    () {
      final result = engine
          .rankCandidates(
            currentUser: _profile(
              preferences: const {
                'ageRange': '25-35',
                'distancePreference': 'Same Country',
                'dealBreakers': ['Heavy drinking', 'Poor communication'],
                'relationshipExpectations': 'Strong long-term alignment',
              },
            ),
            candidates: [_profile(id: 'candidate')],
          )
          .single;
      final text = _allInsightText(result.insights).toLowerCase();

      expect(text, isNot(contains('deal breaker')));
      expect(text, isNot(contains('heavy drinking')));
      expect(text, isNot(contains('age range')));
      expect(text, isNot(contains('same country')));
    },
  );

  test('negative sensitive comparisons are not shown', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(),
          candidates: [
            _profile(
              id: 'candidate',
              lifestyle: const {
                'smoking': 'Regularly',
                'drinking': 'Often',
                'religionImportance': 'Not important',
              },
              relationshipGoals: const {'children': 'Do not want children'},
            ),
          ],
        )
        .single;
    final text = _allInsightText(result.insights).toLowerCase();

    expect(text, isNot(contains('disagree')));
    expect(text, isNot(contains('drinks')));
    expect(text, isNot(contains('religion')));
    expect(text, isNot(contains('poorly')));
  });

  test('insights are deterministic and stronger insights appear first', () {
    final first = engine
        .rankCandidates(
          currentUser: _profile(),
          candidates: [_profile(id: 'candidate')],
        )
        .single;
    final second = engine
        .rankCandidates(
          currentUser: _profile(),
          candidates: [_profile(id: 'candidate')],
        )
        .single;

    expect(
      second.insights.map((insight) => insight.toMap()).toList(),
      first.insights.map((insight) => insight.toMap()).toList(),
    );
    expect(first.insights.first.category, 'relationshipGoals');
  });

  test('category breakdown uses stored category scores', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(),
          candidates: [_profile(id: 'candidate')],
        )
        .single;
    final match = _matchFromResult(result);

    expect(match.categoryScores, result.categoryScores);
  });

  test('missing questionnaire answers do not crash insight generation', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(
            interests: const [],
            lifestyle: const {},
            relationshipGoals: const {},
            personality: const {},
            preferences: const {},
          ),
          candidates: [
            _profile(
              id: 'candidate',
              interests: const [],
              lifestyle: const {},
              relationshipGoals: const {},
              personality: const {},
              preferences: const {},
            ),
          ],
        )
        .single;

    expect(result.insights, isA<List<CompatibilityInsight>>());
  });

  test(
    "low data completeness does not expose the other user's completeness",
    () {
      final result = engine
          .rankCandidates(
            currentUser: _profile(lifestyle: const {}, personality: const {}),
            candidates: [
              _profile(
                id: 'candidate',
                lifestyle: const {},
                personality: const {},
                relationshipGoals: const {'marriage': 'Open to it'},
              ),
            ],
          )
          .single;
      final text = _allInsightText(result.insights).toLowerCase();

      expect(result.dataCompleteness, lessThan(0.5));
      expect(text, isNot(contains('confidence')));
      expect(text, isNot(contains('completed')));
    },
  );

  test(
    'recommendation stores compatibility snapshot and algorithm version',
    () {
      final result = engine
          .rankCandidates(
            currentUser: _profile(),
            candidates: [_profile(id: 'candidate')],
          )
          .single;
      final match = MatchModel.fromMap('a_b', _matchFromResult(result).toMap());

      expect(match.compatibilityScore, result.compatibilityScore);
      expect(
        match.compatibilityReasons.map((i) => i.title),
        result.insights.map((i) => i.title),
      );
      expect(
        match.compatibilityAlgorithmVersion,
        CompatibilityInsightService.algorithmVersion,
      );
    },
  );

  test(
    "changing questionnaire answers later does not alter an existing suggestion's snapshot",
    () {
      final original = engine
          .rankCandidates(
            currentUser: _profile(),
            candidates: [_profile(id: 'candidate')],
          )
          .single;
      final match = _matchFromResult(original);
      final changed = engine
          .rankCandidates(
            currentUser: _profile(
              relationshipGoals: const {'children': 'Do not want children'},
            ),
            candidates: [_profile(id: 'candidate')],
          )
          .single;

      expect(match.compatibilityScore, original.compatibilityScore);
      expect(match.categoryScores, original.categoryScores);
      expect(match.compatibilityScore, isNot(changed.compatibilityScore));
    },
  );

  test('mutual matches retain compatibility insights', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(),
          candidates: [_profile(id: 'candidate')],
        )
        .single;
    final match = _matchFromResult(result, status: MatchStatus.mutual);

    expect(match.status, MatchStatus.mutual);
    expect(match.compatibilityReasons, isNotEmpty);
  });

  test('free users can see core compatibility explanation', () {
    final free = _subscription(SubscriptionTier.free);
    final result = engine
        .rankCandidates(
          currentUser: _profile(),
          candidates: [_profile(id: 'candidate')],
        )
        .single;

    expect(free.hasPremiumAccess, isFalse);
    expect(result.insights, isNotEmpty);
    expect(result.categoryScores, isNotEmpty);
  });

  test('Premium status does not change compatibility percentage or quotas', () {
    final current = _profile();
    final candidate = _profile(id: 'candidate');
    final basic = engine
        .rankCandidates(currentUser: current, candidates: [candidate])
        .single;
    final premium = engine
        .rankCandidates(
          currentUser: current,
          candidates: [candidate],
          priorityMatching: true,
        )
        .single;

    expect(premium.compatibilityScore, basic.compatibilityScore);
    expect(_subscription(SubscriptionTier.free).weeklyMatchQuota, 1);
    expect(_subscription(SubscriptionTier.premium).weeklyMatchQuota, 3);
  });
}

String _allInsightText(List<CompatibilityInsight> insights) {
  return insights
      .map((insight) => '${insight.title} ${insight.description}')
      .join(' ');
}

MatchModel _matchFromResult(
  dynamic result, {
  MatchStatus status = MatchStatus.suggested,
}) {
  return MatchModel(
    id: 'a_b',
    userId: 'a',
    partnerId: result.profile.user.id as String,
    compatibilityScore: result.compatibilityScore as int,
    status: status,
    compatibilityReasons: result.insights as List<CompatibilityInsight>,
    categoryScores: result.categoryScores as Map<String, int>,
    categoryDataCompleteness:
        result.categoryDataCompleteness as Map<String, double>,
    dataCompleteness: result.dataCompleteness as double,
    compatibilityAlgorithmVersion: result.algorithmVersion as int,
    createdAt: DateTime.utc(2026, 1, 1),
    expiresAt: DateTime.utc(2026, 1, 8),
    pairKey: 'a_b',
    participantIds: const ['a', 'b'],
    suggestedForUserIds: const ['a'],
  );
}

SubscriptionModel _subscription(SubscriptionTier tier) {
  return SubscriptionModel(
    id: tier.name,
    userId: 'user',
    tier: tier,
    platform: tier == SubscriptionTier.premium
        ? SubscriptionPlatform.revenueCat
        : SubscriptionPlatform.unknown,
    isActive: tier == SubscriptionTier.premium,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

CompatibilityProfile _profile({
  String id = 'current',
  List<String> interests = const ['Travel', 'Cooking', 'Music'],
  Map<String, String> lifestyle = const {
    'smoking': 'Never',
    'drinking': 'Rarely',
    'religionImportance': 'Important',
    'exerciseFrequency': '3-4 times a week',
    'dietPreference': 'Vegetarian',
    'sleepingSchedule': 'Balanced',
    'socialLifestyle': 'Balanced',
  },
  Map<String, String> relationshipGoals = const {
    'marriage': 'Open to it',
    'longTermRelationship': 'Very important',
    'casualDating': 'Depends on the person',
    'children': 'Open to children',
    'familyImportance': 'Very important',
    'careerPriority': 'Balanced with personal life',
  },
  Map<String, String> personality = const {
    'introvertExtrovert': 'Deep introvert',
    'planningVsSpontaneous': 'Love a plan',
    'riskTaking': 'Very cautious',
    'communicationStyle': 'Direct and clear',
    'conflictResolution': 'Work toward compromise',
    'humorStyle': 'Dry and witty',
  },
  Map<String, dynamic> preferences = const {
    'ageRange': '25-35',
    'distancePreference': 'Same Country',
    'dealBreakers': <String>[],
    'relationshipExpectations': 'Strong long-term alignment',
  },
  double? latitude,
  double? longitude,
}) {
  return CompatibilityProfile(
    user: AppUser(
      id: id,
      email: '$id@example.com',
      displayName: id,
      age: 29,
      gender: id == 'current' ? 'Woman' : 'Man',
      interestedIn: id == 'current' ? const ['Men'] : const ['Women'],
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      country: 'United States',
      city: 'Chicago',
      latitude: latitude,
      longitude: longitude,
    ),
    interests: interests,
    lifestyleAnswers: lifestyle,
    relationshipGoalAnswers: relationshipGoals,
    personalityAnswers: personality,
    preferenceAnswers: preferences,
  );
}
