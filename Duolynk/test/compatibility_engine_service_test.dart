import 'package:flutter_test/flutter_test.dart';

import 'package:duolynk/models/app_user.dart';
import 'package:duolynk/models/compatibility_profile.dart';
import 'package:duolynk/models/subscription_model.dart';
import 'package:duolynk/services/matching/compatibility_engine_service.dart';
import 'package:duolynk/services/matching/match_eligibility_service.dart';

void main() {
  const engine = CompatibilityEngineService();

  test('exact answers produce strong compatibility', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(),
          candidates: [_profile(id: 'candidate')],
        )
        .single;

    expect(result.compatibilityScore, greaterThanOrEqualTo(95));
    expect(
      result.categoryScores.values,
      everyElement(inInclusiveRange(0, 100)),
    );
    expect(result.strongestCategories, isNotEmpty);
  });

  test('adjacent ordinal personality answers score highly', () {
    final adjacent = engine.scorePersonalityAnswer(
      'introvertExtrovert',
      'deep introvert',
      'mostly introvert',
    );
    final distant = engine.scorePersonalityAnswer(
      'introvertExtrovert',
      'deep introvert',
      'high-energy extrovert',
    );

    expect(adjacent, greaterThan(0.75));
    expect(adjacent, greaterThan(distant));
  });

  test('distant ordinal personality answers score lower', () {
    final distant = engine.scorePersonalityAnswer(
      'riskTaking',
      'very cautious',
      'big risk taker',
    );

    expect(distant, lessThan(0.5));
    expect(distant, greaterThanOrEqualTo(0));
  });

  test(
    'lifestyle adjacent answers score better than strongly different answers',
    () {
      final adjacent = engine.scoreLifestyleAnswer(
        'drinking',
        'never',
        'rarely',
      );
      final distant = engine.scoreLifestyleAnswer('drinking', 'never', 'often');

      expect(adjacent, greaterThan(distant));
      expect(adjacent, greaterThan(0.75));
    },
  );

  test(
    'relationship-goal compatible differences receive partial or high scores',
    () {
      final compatible = engine.scoreRelationshipAnswer(
        'children',
        'definitely want children',
        'open to children',
      );

      expect(compatible, greaterThanOrEqualTo(0.75));
      expect(compatible, lessThan(1));
    },
  );

  test('relationship conflicts receive lower scores', () {
    final conflict = engine.scoreRelationshipAnswer(
      'children',
      'definitely want children',
      'do not want children',
    );

    expect(conflict, lessThan(0.3));
  });

  test(
    'multi-select interest overlap works for meaningful shared interests',
    () {
      final result = engine
          .rankCandidates(
            currentUser: _profile(
              interests: const ['Travel', 'Cooking', 'Fitness', 'Movies'],
            ),
            candidates: [
              _profile(
                id: 'candidate',
                interests: const ['Travel', 'Fitness', 'Reading'],
              ),
            ],
          )
          .single;

      expect(result.categoryScores['interests'], greaterThanOrEqualTo(45));
      expect(result.categoryScores['interests'], lessThan(100));
    },
  );

  test("different-sized interest lists don't create misleading results", () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(interests: const ['Travel', 'Cooking']),
          candidates: [
            _profile(
              id: 'candidate',
              interests: const [
                'Travel',
                'Cooking',
                'Reading',
                'Fitness',
                'Movies',
              ],
            ),
          ],
        )
        .single;

    expect(result.categoryScores['interests'], greaterThan(70));
    expect(result.categoryScores['interests'], lessThan(100));
  });

  test('missing answers are excluded rather than scored as zero', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(
            interests: const [],
            lifestyle: const {},
            personality: const {},
            relationshipGoals: const {'marriage': 'Definitely want it'},
            preferences: const {},
            country: null,
            city: null,
          ),
          candidates: [
            _profile(
              id: 'candidate',
              interests: const [],
              lifestyle: const {},
              personality: const {},
              relationshipGoals: const {'marriage': 'Definitely want it'},
              preferences: const {},
              country: null,
              city: null,
            ),
          ],
        )
        .single;

    expect(result.compatibilityScore, 100);
    expect(result.dataCompleteness, lessThan(0.1));
  });

  test("incomplete questionnaire doesn't crash", () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(lifestyle: const {}, personality: const {}),
          candidates: [_profile(id: 'candidate', relationshipGoals: const {})],
        )
        .single;

    expect(result.compatibilityScore, inInclusiveRange(0, 100));
  });

  test('compatibility score is deterministic', () {
    final current = _profile();
    final candidate = _profile(
      id: 'candidate',
      personality: const {'introvertExtrovert': 'Mostly introvert'},
    );

    final first = engine
        .rankCandidates(currentUser: current, candidates: [candidate])
        .single;
    final second = engine
        .rankCandidates(currentUser: current, candidates: [candidate])
        .single;

    expect(second.compatibilityScore, first.compatibilityScore);
    expect(second.dataCompleteness, first.dataCompleteness);
    expect(second.categoryScores, first.categoryScores);
  });

  test('all category and overall scores stay within valid bounds', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(),
          candidates: [
            _profile(
              id: 'candidate',
              relationshipGoals: const {
                'marriage': 'Do not want it',
                'longTermRelationship': 'Not looking for that',
                'casualDating': 'Prefer casual right now',
                'children': 'Do not want children',
              },
              personality: const {'riskTaking': 'Big risk taker'},
            ),
          ],
        )
        .single;

    expect(result.compatibilityScore, inInclusiveRange(0, 100));
    expect(
      result.categoryScores.values,
      everyElement(inInclusiveRange(0, 100)),
    );
    expect(
      result.categoryDataCompleteness.values,
      everyElement(inInclusiveRange(0, 1)),
    );
  });

  test('confidence/completeness increases with more comparable answers', () {
    final sparse = engine
        .rankCandidates(
          currentUser: _profile(lifestyle: const {}, personality: const {}),
          candidates: [
            _profile(
              id: 'sparse',
              lifestyle: const {},
              personality: const {},
              relationshipGoals: const {'marriage': 'Open to it'},
            ),
          ],
        )
        .single;
    final complete = engine
        .rankCandidates(
          currentUser: _profile(),
          candidates: [_profile(id: 'complete')],
        )
        .single;

    expect(complete.dataCompleteness, greaterThan(sparse.dataCompleteness));
  });

  test(
    'high score with extremely low data does not dominate close full profile',
    () {
      final current = _profile(interests: const ['Travel']);
      final thin = _profile(
        id: 'thin',
        interests: const ['Travel'],
        lifestyle: const {},
        relationshipGoals: const {},
        personality: const {},
        preferences: const {},
        country: null,
        city: null,
      );
      final fuller = _profile(
        id: 'fuller',
        interests: const ['Travel'],
        personality: const {
          'introvertExtrovert': 'Mostly introvert',
          'planningVsSpontaneous': 'Usually organized',
          'riskTaking': 'Thoughtfully careful',
          'communicationStyle': 'Warm and reflective',
          'conflictResolution': 'Work toward compromise',
          'humorStyle': 'Observational',
        },
      );

      final ranked = engine.rankCandidates(
        currentUser: current,
        candidates: [thin, fuller],
      );

      expect(ranked.first.profile.user.id, 'fuller');
      expect(
        ranked.first.dataCompleteness,
        greaterThan(ranked.last.dataCompleteness),
      );
    },
  );

  test('eligibility filters still run before compatibility scoring', () {
    final current = _profile();
    final ineligible = _profile(
      id: 'ineligible',
      userGender: 'Man',
      interestedIn: const ['Men'],
    );

    final eligibility = const MatchEligibilityService().evaluate(
      currentUser: current,
      candidate: ineligible,
    );
    final ranked = eligibility.eligible
        ? engine.rankCandidates(currentUser: current, candidates: [ineligible])
        : const [];

    expect(eligibility.eligible, isFalse);
    expect(ranked, isEmpty);
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
  String userGender = 'Woman',
  List<String> interestedIn = const ['Men'],
  String? country = 'United States',
  String? city = 'Chicago',
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
}) {
  return CompatibilityProfile(
    user: AppUser(
      id: id,
      email: '$id@example.com',
      displayName: id,
      age: age,
      gender: userGender,
      interestedIn: interestedIn,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      country: country,
      city: city,
    ),
    interests: interests,
    lifestyleAnswers: lifestyle,
    relationshipGoalAnswers: relationshipGoals,
    personalityAnswers: personality,
    preferenceAnswers: preferences,
  );
}
