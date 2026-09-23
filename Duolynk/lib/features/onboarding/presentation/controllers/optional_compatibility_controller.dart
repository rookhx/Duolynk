import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/compatibility_question_schema.dart';
import '../../../../core/config/questionnaire_ids.dart';
import '../../../../services/analytics/analytics_event_service.dart';
import '../../data/onboarding_repository.dart';
import '../../domain/optional_compatibility_state.dart';

final optionalCompatibilityControllerProvider =
    AsyncNotifierProvider<
      OptionalCompatibilityController,
      OptionalCompatibilityState
    >(OptionalCompatibilityController.new);

class OptionalCompatibilityController
    extends AsyncNotifier<OptionalCompatibilityState> {
  static const String questionnaireId = QuestionnaireIds.optionalCompatibility;

  static const affectionOptions = [
    'Quality time',
    'Physical affection',
    'Words of affirmation',
    'Thoughtful actions',
    'Small gifts',
  ];

  static const financialAttitudeOptions = [
    'Careful saver',
    'Mostly save but enjoy spending',
    'Balanced',
    'Spend on experiences',
    'Spontaneous spender',
  ];

  static const petOptions = [
    'Have or love pets',
    'Would like pets',
    'Neutral',
    'Prefer not to live with pets',
  ];

  static const relocationOptions = [
    'No',
    'Only locally',
    'Within my country',
    'Internationally',
    'Open to possibilities',
  ];

  static const importanceOptions = [
    'Not important',
    'Somewhat important',
    'Important',
    'Very important',
  ];

  @override
  Future<OptionalCompatibilityState> build() async {
    final draft = await ref
        .read(onboardingRepositoryProvider)
        .fetchDraft(questionnaireId: questionnaireId);
    final answers = Map<String, dynamic>.from(draft?.answers ?? const {});
    answers.remove('category');
    answers.remove('questionnaireVersion');
    return OptionalCompatibilityState(answers: answers);
  }

  void toggleAffectionStyle(String value) {
    final current = Map<String, dynamic>.from(state.requireValue.answers);
    final selected = (current['affectionStyles'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    if (selected.contains(value)) {
      selected.remove(value);
    } else {
      selected.add(value);
    }
    current['affectionStyles'] = selected;
    state = AsyncData(state.requireValue.copyWith(answers: current));
  }

  void selectAnswer({required String key, required String value}) {
    final current = Map<String, dynamic>.from(state.requireValue.answers);
    current[key] = value;
    state = AsyncData(state.requireValue.copyWith(answers: current));
  }

  Future<void> save() async {
    await const AnalyticsEventService().track('optional_questions_started');
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isSaving: true));
    try {
      await ref
          .read(onboardingRepositoryProvider)
          .persistDraft(
            questionnaireId: questionnaireId,
            answers: {
              'category': 'optional_compatibility',
              'questionnaireVersion':
                  CompatibilityQuestionSchema.questionnaireVersion,
              ...current.answers,
            },
            completedSteps: current.completedCount,
            totalSteps: CompatibilityQuestionSchema.optionalQuestions.length,
            isComplete:
                current.completedCount ==
                CompatibilityQuestionSchema.optionalQuestions.length,
          );
      await const AnalyticsEventService().track('optional_questions_completed');
      state = AsyncData(current.copyWith(isSaving: false));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
