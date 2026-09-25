import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/compatibility_question_schema.dart';
import '../../../../core/routing/app_route_paths.dart';
import '../../../../services/analytics/analytics_event_service.dart';
import '../../data/onboarding_repository.dart';
import '../../domain/questionnaire_one_state.dart';

final questionnaireOneControllerProvider =
    AsyncNotifierProvider<QuestionnaireOneController, QuestionnaireOneState>(
      QuestionnaireOneController.new,
    );

class QuestionnaireOneController extends AsyncNotifier<QuestionnaireOneState> {
  static const String questionnaireId = 'questionnaire_one_interests';

  static const List<String> availableInterests = [
    'Travel',
    'Reading',
    'Fitness',
    'Cooking',
    'Gaming',
    'Photography',
    'Technology',
    'Business',
    'Music',
    'Movies',
  ];

  @override
  Future<QuestionnaireOneState> build() async {
    final draft = await ref
        .read(onboardingRepositoryProvider)
        .fetchDraft(questionnaireId: questionnaireId);

    final saved =
        (draft?.answers['selectedInterests'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList();

    return QuestionnaireOneState(selectedInterests: saved);
  }

  void toggleInterest(String interest) {
    final current = [...state.requireValue.selectedInterests];
    if (current.contains(interest)) {
      current.remove(interest);
    } else {
      current.add(interest);
    }
    state = AsyncData(state.requireValue.copyWith(selectedInterests: current));
  }

  Future<void> saveSelections() async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isSaving: true));

    try {
      await ref
          .read(onboardingRepositoryProvider)
          .persistDraft(
            questionnaireId: questionnaireId,
            answers: {
              'category': 'interests',
              'questionnaireVersion':
                  CompatibilityQuestionSchema.questionnaireVersion,
              'selectedInterests': current.selectedInterests,
            },
            completedSteps: 1,
            totalSteps: 1,
            isComplete: true,
          );
      await ref
          .read(onboardingRepositoryProvider)
          .updateOnboardingStep(AppRoutePaths.questionnaireTwo);
      await const AnalyticsEventService().track(
        'compatibility_profile_started',
      );

      state = AsyncData(current.copyWith(isSaving: false));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
