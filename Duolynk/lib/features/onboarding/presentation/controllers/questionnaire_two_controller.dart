import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/compatibility_question_schema.dart';
import '../../../../core/routing/app_route_paths.dart';
import '../../data/onboarding_repository.dart';
import '../../domain/questionnaire_two_state.dart';

final questionnaireTwoControllerProvider =
    AsyncNotifierProvider<QuestionnaireTwoController, QuestionnaireTwoState>(
      QuestionnaireTwoController.new,
    );

class QuestionnaireTwoController extends AsyncNotifier<QuestionnaireTwoState> {
  static const String questionnaireId = 'questionnaire_two_lifestyle';

  static const Map<String, List<String>> questions = {
    'smoking': [
      'Never',
      'Occasionally',
      'Socially',
      'Regularly',
      'Prefer not to say',
    ],
    'drinking': ['Never', 'Rarely', 'Socially', 'Often', 'Prefer not to say'],
    'religionImportance': [
      'Not important',
      'Somewhat important',
      'Important',
      'Very important',
    ],
    'exerciseFrequency': [
      'Rarely',
      '1-2 times a week',
      '3-4 times a week',
      '5+ times a week',
    ],
    'dietPreference': [
      'No preference',
      'Vegetarian',
      'Vegan',
      'Pescatarian',
      'Halal',
      'Kosher',
      'Other',
    ],
    'sleepingSchedule': [
      'Early bird',
      'Balanced',
      'Night owl',
      'Depends on the week',
    ],
    'socialLifestyle': [
      'Homebody',
      'Balanced',
      'Social and outgoing',
      'Very active socially',
    ],
  };

  @override
  Future<QuestionnaireTwoState> build() async {
    final draft = await ref
        .read(onboardingRepositoryProvider)
        .fetchDraft(questionnaireId: questionnaireId);

    final rawAnswers = Map<String, dynamic>.from(draft?.answers ?? const {});
    final savedAnswers = <String, String>{};

    for (final key in questions.keys) {
      final value = rawAnswers[key];
      if (value is String && value.isNotEmpty) {
        savedAnswers[key] = value;
      }
    }

    return QuestionnaireTwoState(answers: savedAnswers);
  }

  void selectAnswer({required String questionKey, required String answer}) {
    final current = Map<String, String>.from(state.requireValue.answers);
    current[questionKey] = answer;
    state = AsyncData(state.requireValue.copyWith(answers: current));
  }

  Future<void> saveResults() async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isSaving: true));

    try {
      await ref
          .read(onboardingRepositoryProvider)
          .persistDraft(
            questionnaireId: questionnaireId,
            answers: {
              'category': 'lifestyle',
              'questionnaireVersion':
                  CompatibilityQuestionSchema.questionnaireVersion,
              ...current.answers,
            },
            completedSteps: current.answers.length.clamp(0, questions.length),
            totalSteps: questions.length,
            isComplete: current.isComplete,
          );
      await ref
          .read(onboardingRepositoryProvider)
          .updateOnboardingStep(AppRoutePaths.questionnaireThree);

      state = AsyncData(current.copyWith(isSaving: false));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
