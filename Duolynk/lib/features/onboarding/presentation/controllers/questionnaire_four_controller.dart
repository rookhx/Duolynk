import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/compatibility_question_schema.dart';
import '../../../../core/routing/app_route_paths.dart';
import '../../data/onboarding_repository.dart';
import '../../domain/questionnaire_four_state.dart';

final questionnaireFourControllerProvider =
    AsyncNotifierProvider<QuestionnaireFourController, QuestionnaireFourState>(
      QuestionnaireFourController.new,
    );

class QuestionnaireFourController
    extends AsyncNotifier<QuestionnaireFourState> {
  static const String questionnaireId = 'questionnaire_four_relationship_goals';

  static const Map<String, List<String>> questions = {
    'marriage': [
      'Definitely want it',
      'Open to it',
      'Unsure',
      'Not a priority',
      'Do not want it',
    ],
    'longTermRelationship': [
      'Essential',
      'Very important',
      'Open to it',
      'Not sure yet',
      'Not looking for that',
    ],
    'casualDating': [
      'Not interested',
      'Open in the short term',
      'Depends on the person',
      'Comfortable with it',
      'Prefer casual right now',
    ],
    'children': [
      'Definitely want children',
      'Open to children',
      'Unsure',
      'Do not want children',
      'Already have children',
    ],
    'familyImportance': [
      'Central to my life',
      'Very important',
      'Important',
      'Somewhat important',
      'Less important',
    ],
    'careerPriority': [
      'Top priority right now',
      'Very important',
      'Balanced with personal life',
      'Flexible',
      'Personal life comes first',
    ],
    'livingTogether': [
      'Only after deep commitment',
      'Open when the relationship is serious',
      'Comfortable if timing feels right',
      'Prefer to keep separate homes',
    ],
  };

  @override
  Future<QuestionnaireFourState> build() async {
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

    return QuestionnaireFourState(answers: savedAnswers);
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
              'category': 'relationship_goals',
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
          .updateOnboardingStep(AppRoutePaths.questionnaireFive);

      state = AsyncData(current.copyWith(isSaving: false));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
