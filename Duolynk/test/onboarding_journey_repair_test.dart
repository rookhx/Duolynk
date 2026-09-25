import 'package:duolynk/core/config/compatibility_question_schema.dart';
import 'package:duolynk/features/auth/domain/auth_session.dart';
import 'package:duolynk/models/app_user.dart';
import 'package:duolynk/models/profile_prompt_answer.dart';
import 'package:duolynk/models/questionnaire_model.dart';
import 'package:duolynk/services/matching/compatibility_profile_completion_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('required questionnaire schema still contains 26 fields', () {
    expect(CompatibilityQuestionSchema.requiredQuestions.length, 26);
    expect(CompatibilityQuestionSchema.optionalQuestions.length, 6);
  });

  test('three public prompts do not complete new-user onboarding alone', () {
    final user = _newUser(
      isProfileComplete: false,
      datingProfileComplete: true,
      requiredCompatibilityComplete: false,
      onboardingStep: '/onboarding/questionnaire-one',
    );

    expect(user.datingProfileComplete, isTrue);
    expect(user.requiredCompatibilityComplete, isFalse);
    expect(user.hasCompletedRequiredOnboarding, isFalse);
    expect(
      AuthSession(user: user, isAuthenticated: true).needsOnboarding,
      isTrue,
    );
  });

  test(
    'completed dating profile plus required questionnaire completes onboarding',
    () {
      final user = _newUser(
        isProfileComplete: true,
        datingProfileComplete: true,
        requiredCompatibilityComplete: true,
      );

      expect(user.hasCompletedRequiredOnboarding, isTrue);
      expect(
        AuthSession(user: user, isAuthenticated: true).needsOnboarding,
        isFalse,
      );
    },
  );

  test('legacy completed account can still enter app shell safely', () {
    final legacy = AppUser.fromMap('legacy', {
      'email': 'legacy@example.com',
      'displayName': 'Legacy',
      'age': 31,
      'gender': 'Woman',
      'interestedIn': ['Men'],
      'createdAt': DateTime.utc(2026, 1, 1),
      'updatedAt': DateTime.utc(2026, 1, 1),
      'isProfileComplete': true,
    });

    expect(legacy.datingProfileVersion, 0);
    expect(legacy.hasCompletedRequiredOnboarding, isTrue);
  });

  test(
    'missing required compatibility answers are not counted as complete',
    () {
      final service = const CompatibilityProfileCompletionService();
      final partial = [
        _questionnaire('questionnaire_one_interests', {
          'selectedInterests': ['Travel', 'Cooking'],
        }),
      ];

      expect(service.hasCompletedRequiredProfile(partial), isFalse);
    },
  );

  test('all required compatibility answers are required for completion', () {
    final service = const CompatibilityProfileCompletionService();
    final complete = [
      _questionnaire('questionnaire_one_interests', {
        'selectedInterests': ['Travel', 'Cooking'],
      }),
      _questionnaire('questionnaire_two_lifestyle', {
        'smoking': 'Never',
        'drinking': 'Rarely',
        'religionImportance': 'Somewhat important',
        'exerciseFrequency': '3-4 times a week',
        'dietPreference': 'No preference',
        'sleepingSchedule': 'Balanced',
        'socialLifestyle': 'Balanced',
      }),
      _questionnaire('questionnaire_three_personality', {
        'introvertExtrovert': 'Balanced',
        'planningVsSpontaneous': 'Usually organized',
        'riskTaking': 'Balanced',
        'communicationStyle': 'Direct and clear',
        'communicationFrequency': 'A few meaningful check-ins',
        'conflictResolution': 'Work toward compromise',
        'humorStyle': 'Warm and wholesome',
      }),
      _questionnaire('questionnaire_four_relationship_goals', {
        'marriage': 'Open to it',
        'longTermRelationship': 'Very important',
        'casualDating': 'Depends on the person',
        'children': 'Open to children',
        'familyImportance': 'Important',
        'careerPriority': 'Balanced with personal life',
        'livingTogether': 'Open when the relationship is serious',
      }),
      _questionnaire('questionnaire_five_preferences_deal_breakers', {
        'ageRange': '25-30',
        'distancePreference': 'Same City',
        'dealBreakers': ['No deal breakers right now'],
        'relationshipExpectations': 'Consistent communication',
      }),
    ];

    expect(service.hasCompletedRequiredProfile(complete), isTrue);
  });
}

AppUser _newUser({
  required bool isProfileComplete,
  required bool datingProfileComplete,
  required bool requiredCompatibilityComplete,
  String? onboardingStep,
}) {
  return AppUser(
    id: 'new-user',
    email: 'new@example.com',
    displayName: 'New User',
    age: 30,
    gender: 'Woman',
    interestedIn: const ['Men'],
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    country: 'United States',
    city: 'Chicago',
    bio: 'Intentional and ready for a thoughtful introduction.',
    photoUrl: 'photo',
    photoUrls: const ['photo'],
    profilePrompts: const [
      ProfilePromptAnswer(promptId: 'perfect_weekend', answer: 'Coffee.'),
      ProfilePromptAnswer(promptId: 'ideal_first_date', answer: 'A walk.'),
      ProfilePromptAnswer(promptId: 'green_flag', answer: 'Kindness.'),
    ],
    datingProfileVersion: 1,
    isProfileComplete: isProfileComplete,
    datingProfileComplete: datingProfileComplete,
    requiredCompatibilityComplete: requiredCompatibilityComplete,
    onboardingStep: onboardingStep,
  );
}

QuestionnaireModel _questionnaire(String id, Map<String, dynamic> answers) {
  return QuestionnaireModel(
    id: id,
    userId: 'new-user',
    answers: answers,
    completedSteps: answers.length,
    totalSteps: answers.length,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    isComplete: true,
    questionnaireVersion: CompatibilityQuestionSchema.questionnaireVersion,
  );
}
