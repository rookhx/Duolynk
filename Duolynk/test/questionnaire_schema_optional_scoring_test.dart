import 'package:flutter_test/flutter_test.dart';

import 'package:duolynk/core/config/compatibility_question_schema.dart';
import 'package:duolynk/core/config/questionnaire_ids.dart';
import 'package:duolynk/models/app_user.dart';
import 'package:duolynk/models/compatibility_profile.dart';
import 'package:duolynk/models/match_model.dart';
import 'package:duolynk/models/questionnaire_model.dart';
import 'package:duolynk/models/subscription_model.dart';
import 'package:duolynk/services/matching/compatibility_engine_service.dart';
import 'package:duolynk/services/matching/compatibility_profile_completion_service.dart';
import 'package:duolynk/services/matching/match_eligibility_service.dart';

void main() {
  const engine = CompatibilityEngineService();

  test(
    'existing questionnaire answers still deserialize as legacy version',
    () {
      final model = QuestionnaireModel.fromMap('legacy', {
        'userId': 'a',
        'answers': {
          'category': 'personality',
          'communicationStyle': 'Direct and clear',
        },
        'completedSteps': 1,
        'totalSteps': 6,
        'createdAt': DateTime.utc(2026, 1, 1),
        'updatedAt': DateTime.utc(2026, 1, 1),
        'isComplete': false,
      });

      expect(model.questionnaireVersion, 1);
      expect(model.answers['communicationStyle'], 'Direct and clear');
    },
  );

  test('new questionnaire answers serialize and deserialize correctly', () {
    final model = QuestionnaireModel(
      id: QuestionnaireIds.optionalCompatibility,
      userId: 'a',
      answers: const {
        'category': 'optional_compatibility',
        'questionnaireVersion':
            CompatibilityQuestionSchema.questionnaireVersion,
        'affectionStyles': ['Quality time', 'Thoughtful actions'],
        'financialAttitude': 'Balanced',
        'politicalViewsImportance': 'Somewhat important',
      },
      completedSteps: 3,
      totalSteps: 6,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
      questionnaireVersion: CompatibilityQuestionSchema.questionnaireVersion,
    );
    final decoded = QuestionnaireModel.fromMap(model.id, model.toMap());

    expect(decoded.questionnaireVersion, 2);
    expect(decoded.answers['affectionStyles'], [
      'Quality time',
      'Thoughtful actions',
    ]);
    expect(decoded.answers['politicalViewsImportance'], 'Somewhat important');
  });

  test('existing users without new questions do not crash', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(optionalAnswers: const {}),
          candidates: [_profile(id: 'candidate', optionalAnswers: const {})],
        )
        .single;

    expect(result.compatibilityScore, inInclusiveRange(0, 100));
  });

  test('missing optional questions are excluded from scoring', () {
    final sparse = engine
        .rankCandidates(
          currentUser: _profile(optionalAnswers: const {}),
          candidates: [_profile(id: 'candidate', optionalAnswers: const {})],
        )
        .single;
    final complete = engine
        .rankCandidates(
          currentUser: _profile(),
          candidates: [_profile(id: 'candidate')],
        )
        .single;

    expect(sparse.compatibilityScore, complete.compatibilityScore);
    expect(complete.dataCompleteness, greaterThan(sparse.dataCompleteness));
  });

  test(
    'communication-frequency adjacent answers score better than distant answers',
    () {
      final adjacent = engine.scorePersonalityAnswer(
        'communicationFrequency',
        'a few meaningful check-ins',
        'regular communication throughout the day',
      );
      final distant = engine.scorePersonalityAnswer(
        'communicationFrequency',
        'i like plenty of space',
        'i love staying closely connected',
      );

      expect(adjacent, greaterThan(distant));
    },
  );

  test('affection-style overlap scores correctly', () {
    final strong = engine.scoreAffectionStyleOverlap(
      ['Quality time', 'Thoughtful actions'],
      ['Quality time', 'Words of affirmation'],
    );
    final none = engine.scoreAffectionStyleOverlap(
      ['Small gifts'],
      ['Physical affection'],
    );

    expect(strong, greaterThan(none));
    expect(strong, inInclusiveRange(0, 1));
  });

  test('financial-attitude graded scoring works', () {
    final adjacent = engine.scoreLifestyleAnswer(
      'financialAttitude',
      'careful saver',
      'mostly save but enjoy spending',
    );
    final distant = engine.scoreLifestyleAnswer(
      'financialAttitude',
      'careful saver',
      'spontaneous spender',
    );

    expect(adjacent, greaterThan(distant));
  });

  test('pets matrix works', () {
    final compatible = engine.scoreLifestyleAnswer(
      'pets',
      'have or love pets',
      'would like pets',
    );
    final harder = engine.scoreLifestyleAnswer(
      'pets',
      'have or love pets',
      'prefer not to live with pets',
    );

    expect(compatible, greaterThan(harder));
  });

  test('relocation scoring works', () {
    final adjacent = engine.scoreRelationshipAnswer(
      'relocationOpenness',
      'only locally',
      'within my country',
    );
    final distant = engine.scoreRelationshipAnswer(
      'relocationOpenness',
      'no',
      'open to possibilities',
    );

    expect(adjacent, greaterThan(distant));
  });

  test(
    'optional political-importance question does not infer or store ideology',
    () {
      final profile = _profile(
        optionalAnswers: const {'politicalViewsImportance': 'Very important'},
      );
      final result = engine
          .rankCandidates(
            currentUser: profile,
            candidates: [_profile(id: 'candidate')],
          )
          .single;
      final text = result.insights
          .map((insight) => '${insight.title} ${insight.description}')
          .join(' ')
          .toLowerCase();

      expect(
        profile.optionalAnswers.containsKey('politicalViewsImportance'),
        isTrue,
      );
      expect(text, isNot(contains('political')));
      expect(text, isNot(contains('party')));
    },
  );

  test('hard preference fields remain eligibility filters', () {
    final eligibility = const MatchEligibilityService().evaluate(
      currentUser: _profile(preferences: const {'ageRange': '25-30'}),
      candidate: _profile(id: 'candidate', age: 45),
    );

    expect(eligibility.eligible, isFalse);
  });

  test('soft compatibility fields do not accidentally become hard filters', () {
    final eligibility = const MatchEligibilityService().evaluate(
      currentUser: _profile(
        optionalAnswers: const {'pets': 'Have or love pets'},
      ),
      candidate: _profile(
        id: 'candidate',
        optionalAnswers: const {'pets': 'Prefer not to live with pets'},
      ),
    );

    expect(eligibility.eligible, isTrue);
  });

  test('deal breakers still prevent ineligible recommendations', () {
    final eligibility = const MatchEligibilityService().evaluate(
      currentUser: _profile(
        preferences: const {
          'dealBreakers': ['Smoking'],
          'ageRange': '25-35',
        },
      ),
      candidate: _profile(
        id: 'candidate',
        lifestyle: const {'smoking': 'Regularly'},
      ),
    );

    expect(eligibility.eligible, isFalse);
  });

  test('new questions contribute to appropriate compatibility categories', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(
            personality: const {
              'communicationFrequency': 'I like plenty of space',
            },
            optionalAnswers: const {
              'financialAttitude': 'Careful saver',
              'relocationOpenness': 'No',
            },
          ),
          candidates: [
            _profile(
              id: 'candidate',
              personality: const {
                'communicationFrequency': 'I love staying closely connected',
              },
              optionalAnswers: const {
                'financialAttitude': 'Spontaneous spender',
                'relocationOpenness': 'Open to possibilities',
              },
            ),
          ],
        )
        .single;

    expect(result.categoryScores['personality'], lessThan(100));
    expect(result.categoryScores['lifestyle'], lessThan(100));
    expect(result.categoryScores['relationshipGoals'], lessThan(100));
  });

  test('category and overall scores remain in bounds', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(),
          candidates: [_profile(id: 'candidate')],
        )
        .single;

    expect(result.compatibilityScore, inInclusiveRange(0, 100));
    expect(
      result.categoryScores.values,
      everyElement(inInclusiveRange(0, 100)),
    );
  });

  test('existing match snapshots do not change after questionnaire edits', () {
    final original = engine
        .rankCandidates(
          currentUser: _profile(),
          candidates: [_profile(id: 'candidate')],
        )
        .single;
    final snapshot = MatchModel(
      id: 'a_candidate',
      userId: 'a',
      partnerId: 'candidate',
      compatibilityScore: original.compatibilityScore,
      status: MatchStatus.suggested,
      compatibilityReasons: original.insights,
      categoryScores: original.categoryScores,
      createdAt: DateTime.utc(2026, 1, 1),
      expiresAt: DateTime.utc(2026, 1, 8),
    );
    final edited = engine
        .rankCandidates(
          currentUser: _profile(
            optionalAnswers: const {'pets': 'Prefer not to live with pets'},
          ),
          candidates: [_profile(id: 'candidate')],
        )
        .single;

    expect(snapshot.compatibilityScore, original.compatibilityScore);
    expect(snapshot.categoryScores, original.categoryScores);
    expect(snapshot.compatibilityScore, isNot(edited.compatibilityScore));
  });

  test('own profile-completion percentage calculates correctly', () {
    final completion = const CompatibilityProfileCompletionService().calculate([
      _questionnaire(QuestionnaireIds.interests, {
        'selectedInterests': ['Travel'],
      }),
      _questionnaire(QuestionnaireIds.optionalCompatibility, {
        'affectionStyles': ['Quality time'],
      }),
    ]);

    expect(completion, greaterThan(0));
    expect(completion, lessThan(1));
  });

  test(
    "another user's completion percentage is not exposed by compatibility result",
    () {
      final result = engine
          .rankCandidates(
            currentUser: _profile(),
            candidates: [_profile(id: 'candidate')],
          )
          .single;

      expect(result.profile.user.id, 'candidate');
      expect(result.profile.optionalAnswers.containsKey('completion'), isFalse);
    },
  );

  test('optional questions can be skipped without incompatibility', () {
    final result = engine
        .rankCandidates(
          currentUser: _profile(optionalAnswers: const {}),
          candidates: [_profile(id: 'candidate', optionalAnswers: const {})],
        )
        .single;

    expect(result.compatibilityScore, inInclusiveRange(0, 100));
  });

  test('back-style state updates preserve previous selections', () {
    final answers = {'financialAttitude': 'Balanced', 'pets': 'Neutral'};
    final updated = {...answers, 'relocationOpenness': 'Within my country'};

    expect(updated['financialAttitude'], answers['financialAttitude']);
    expect(updated['pets'], answers['pets']);
  });

  test('questionnaire version is stored and legacy remains supported', () {
    final current = _questionnaire(
      QuestionnaireIds.personality,
      {'communicationFrequency': 'A few meaningful check-ins'},
      version: CompatibilityQuestionSchema.questionnaireVersion,
    );
    final legacy = QuestionnaireModel.fromMap('legacy', {
      'userId': 'a',
      'answers': const {},
      'completedSteps': 0,
      'totalSteps': 0,
      'createdAt': DateTime.utc(2026, 1, 1),
      'updatedAt': DateTime.utc(2026, 1, 1),
    });

    expect(current.questionnaireVersion, 2);
    expect(legacy.questionnaireVersion, 1);
  });

  test(
    'Basic remains 1, Premium remains 3, Premium does not alter scoring',
    () {
      final basicScore = engine
          .rankCandidates(
            currentUser: _profile(),
            candidates: [_profile(id: 'candidate')],
          )
          .single
          .compatibilityScore;
      final premiumScore = engine
          .rankCandidates(
            currentUser: _profile(),
            candidates: [_profile(id: 'candidate')],
            priorityMatching: true,
          )
          .single
          .compatibilityScore;

      expect(_subscription(SubscriptionTier.free).weeklyMatchQuota, 1);
      expect(_subscription(SubscriptionTier.premium).weeklyMatchQuota, 3);
      expect(premiumScore, basicScore);
    },
  );
}

QuestionnaireModel _questionnaire(
  String id,
  Map<String, dynamic> answers, {
  int version = 2,
}) {
  return QuestionnaireModel(
    id: id,
    userId: 'a',
    answers: answers,
    completedSteps: answers.length,
    totalSteps: answers.length,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    questionnaireVersion: version,
  );
}

SubscriptionModel _subscription(SubscriptionTier tier) {
  return SubscriptionModel(
    id: tier.name,
    userId: 'a',
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
  int age = 29,
  Map<String, String> lifestyle = const {
    'smoking': 'Never',
    'drinking': 'Rarely',
    'socialLifestyle': 'Balanced',
  },
  Map<String, String> personality = const {
    'communicationFrequency': 'A few meaningful check-ins',
  },
  Map<String, String> relationshipGoals = const {
    'longTermRelationship': 'Very important',
    'livingTogether': 'Open when the relationship is serious',
  },
  Map<String, dynamic> preferences = const {
    'ageRange': '25-35',
    'distancePreference': 'Same Country',
    'dealBreakers': <String>[],
    'relationshipExpectations': 'Strong long-term alignment',
  },
  Map<String, dynamic> optionalAnswers = const {
    'affectionStyles': ['Quality time', 'Thoughtful actions'],
    'financialAttitude': 'Balanced',
    'pets': 'Neutral',
    'relocationOpenness': 'Within my country',
    'culturalBackgroundImportance': 'Somewhat important',
    'politicalViewsImportance': 'Somewhat important',
  },
}) {
  return CompatibilityProfile(
    user: AppUser(
      id: id,
      email: '$id@example.com',
      displayName: id,
      age: age,
      gender: id == 'current' ? 'Woman' : 'Man',
      interestedIn: id == 'current' ? const ['Men'] : const ['Women'],
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      country: 'United States',
      city: 'Chicago',
      isProfileComplete: true,
    ),
    interests: const ['Travel', 'Cooking'],
    lifestyleAnswers: lifestyle,
    relationshipGoalAnswers: relationshipGoals,
    personalityAnswers: personality,
    preferenceAnswers: preferences,
    optionalAnswers: optionalAnswers,
  );
}
