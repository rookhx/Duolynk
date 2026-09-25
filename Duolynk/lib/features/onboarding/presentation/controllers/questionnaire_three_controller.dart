import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/compatibility_question_schema.dart';
import '../../../../core/routing/app_route_paths.dart';
import '../../data/onboarding_repository.dart';
import '../../domain/questionnaire_three_state.dart';

final questionnaireThreeControllerProvider =
    AsyncNotifierProvider<
      QuestionnaireThreeController,
      QuestionnaireThreeState
    >(QuestionnaireThreeController.new);

class QuestionnaireThreeController
    extends AsyncNotifier<QuestionnaireThreeState> {
  static const String questionnaireId = 'questionnaire_three_personality';

  static const Map<String, List<String>> questions = {
    'introvertExtrovert': [
      'Deep introvert',
      'Mostly introvert',
      'Balanced',
      'Mostly extrovert',
      'High-energy extrovert',
    ],
    'planningVsSpontaneous': [
      'Love a plan',
      'Usually organized',
      'Balanced',
      'Spontaneous often',
      'Go with the flow',
    ],
    'riskTaking': [
      'Very cautious',
      'Thoughtfully careful',
      'Balanced',
      'Comfortably adventurous',
      'Big risk taker',
    ],
    'communicationStyle': [
      'Direct and clear',
      'Warm and reflective',
      'Playful and light',
      'Deep and intentional',
      'Depends on the person',
    ],
    'communicationFrequency': [
      'I like plenty of space',
      'A few meaningful check-ins',
      'Regular communication throughout the day',
      'I love staying closely connected',
    ],
    'conflictResolution': [
      'Need space first',
      'Talk it through quickly',
      'Prefer calm reflection',
      'Work toward compromise',
      'Need emotional reassurance',
    ],
    'humorStyle': [
      'Dry and witty',
      'Sarcastic',
      'Playful and goofy',
      'Observational',
      'Warm and wholesome',
    ],
  };

  @override
  Future<QuestionnaireThreeState> build() async {
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

    return QuestionnaireThreeState(answers: savedAnswers);
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
              'category': 'personality',
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
          .updateOnboardingStep(AppRoutePaths.questionnaireFour);

      state = AsyncData(current.copyWith(isSaving: false));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
