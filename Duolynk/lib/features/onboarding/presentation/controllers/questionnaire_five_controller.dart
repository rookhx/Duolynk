import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/compatibility_question_schema.dart';
import '../../../../services/analytics/analytics_event_service.dart';
import '../../data/onboarding_repository.dart';
import '../../domain/questionnaire_five_state.dart';

final questionnaireFiveControllerProvider =
    AsyncNotifierProvider<QuestionnaireFiveController, QuestionnaireFiveState>(
      QuestionnaireFiveController.new,
    );

class QuestionnaireFiveController
    extends AsyncNotifier<QuestionnaireFiveState> {
  static const String questionnaireId =
      'questionnaire_five_preferences_deal_breakers';

  static const List<String> ageRanges = [
    '18-24',
    '25-30',
    '31-35',
    '36-42',
    '43-50',
    '50+',
  ];

  static const List<String> distancePreferences = [
    'Same City',
    'Same Country',
    'Europe',
    'Worldwide',
  ];

  static const List<String> dealBreakerOptions = [
    'No deal breakers right now',
    'Smoking',
    'Heavy drinking',
    'Not wanting commitment',
    'Different family values',
    'No interest in children',
    'Poor communication',
    'Dishonesty',
    'Long distance only',
  ];

  static const List<String> relationshipExpectationOptions = [
    'Clear commitment early',
    'Take things slowly',
    'Consistent communication',
    'Shared emotional maturity',
    'Strong long-term alignment',
  ];

  @override
  Future<QuestionnaireFiveState> build() async {
    final draft = await ref
        .read(onboardingRepositoryProvider)
        .fetchDraft(questionnaireId: questionnaireId);

    final answers = Map<String, dynamic>.from(draft?.answers ?? const {});

    return QuestionnaireFiveState(
      ageRange: answers['ageRange'] as String?,
      distancePreference: answers['distancePreference'] as String?,
      dealBreakers: (answers['dealBreakers'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      relationshipExpectations: answers['relationshipExpectations'] as String?,
    );
  }

  void selectAgeRange(String value) {
    state = AsyncData(state.requireValue.copyWith(ageRange: value));
  }

  void selectDistancePreference(String value) {
    state = AsyncData(state.requireValue.copyWith(distancePreference: value));
  }

  void toggleDealBreaker(String value) {
    final current = [...state.requireValue.dealBreakers];
    if (value == 'No deal breakers right now') {
      state = AsyncData(
        state.requireValue.copyWith(
          dealBreakers: current.contains(value) ? const [] : [value],
        ),
      );
      return;
    }
    if (current.contains(value)) {
      current.remove(value);
    } else {
      current.remove('No deal breakers right now');
      current.add(value);
    }
    state = AsyncData(state.requireValue.copyWith(dealBreakers: current));
  }

  void selectRelationshipExpectation(String value) {
    state = AsyncData(
      state.requireValue.copyWith(relationshipExpectations: value),
    );
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
              'category': 'preferences_deal_breakers',
              'questionnaireVersion':
                  CompatibilityQuestionSchema.questionnaireVersion,
              'ageRange': current.ageRange,
              'distancePreference': current.distancePreference,
              'dealBreakers': current.dealBreakers,
              'relationshipExpectations': current.relationshipExpectations,
            },
            completedSteps: current.completedCount,
            totalSteps: 4,
            isComplete: current.isComplete,
          );
      await const AnalyticsEventService().track(
        'compatibility_profile_completed',
      );

      state = AsyncData(current.copyWith(isSaving: false));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
