import '../../core/config/compatibility_question_schema.dart';
import '../../core/config/questionnaire_ids.dart';
import '../../models/questionnaire_model.dart';

class CompatibilityProfileCompletionService {
  const CompatibilityProfileCompletionService();

  double calculate(Iterable<QuestionnaireModel> questionnaires) {
    final byId = {
      for (final questionnaire in questionnaires)
        questionnaire.id: questionnaire,
    };
    final answeredRequired = CompatibilityQuestionSchema.requiredQuestions
        .where((definition) => _hasAnswer(byId, definition.key))
        .length;
    final answeredOptional = CompatibilityQuestionSchema.optionalQuestions
        .where((definition) => _hasAnswer(byId, definition.key))
        .length;

    final requiredScore =
        answeredRequired / CompatibilityQuestionSchema.requiredQuestions.length;
    final optionalScore = CompatibilityQuestionSchema.optionalQuestions.isEmpty
        ? 0.0
        : answeredOptional /
              CompatibilityQuestionSchema.optionalQuestions.length;

    // Required onboarding answers represent the core compatibility profile.
    // Optional answers add depth without making legacy users appear broken.
    return ((requiredScore * 0.80) + (optionalScore * 0.20)).clamp(0, 1);
  }

  bool hasCompletedRequiredProfile(
    Iterable<QuestionnaireModel> questionnaires,
  ) {
    final byId = {
      for (final questionnaire in questionnaires)
        questionnaire.id: questionnaire,
    };
    return CompatibilityQuestionSchema.requiredQuestions.every(
      (definition) => _hasAnswer(byId, definition.key),
    );
  }

  bool _hasAnswer(
    Map<String, QuestionnaireModel> questionnairesById,
    String key,
  ) {
    final questionnaire = _questionnaireForKey(questionnairesById, key);
    if (questionnaire == null) {
      return false;
    }
    final value = questionnaire.answers[key];
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    if (value is List) {
      return value.isNotEmpty;
    }
    return value != null;
  }

  QuestionnaireModel? _questionnaireForKey(
    Map<String, QuestionnaireModel> questionnairesById,
    String key,
  ) {
    if (key == 'selectedInterests') {
      return questionnairesById[QuestionnaireIds.interests];
    }
    if (const {
      'smoking',
      'drinking',
      'religionImportance',
      'exerciseFrequency',
      'dietPreference',
      'sleepingSchedule',
      'socialLifestyle',
    }.contains(key)) {
      return questionnairesById[QuestionnaireIds.lifestyle];
    }
    if (const {
      'introvertExtrovert',
      'planningVsSpontaneous',
      'riskTaking',
      'communicationStyle',
      'communicationFrequency',
      'conflictResolution',
      'humorStyle',
    }.contains(key)) {
      return questionnairesById[QuestionnaireIds.personality];
    }
    if (const {
      'marriage',
      'longTermRelationship',
      'casualDating',
      'children',
      'familyImportance',
      'careerPriority',
      'livingTogether',
    }.contains(key)) {
      return questionnairesById[QuestionnaireIds.relationshipGoals];
    }
    if (const {
      'ageRange',
      'distancePreference',
      'dealBreakers',
      'relationshipExpectations',
    }.contains(key)) {
      return questionnairesById[QuestionnaireIds.preferences];
    }
    return questionnairesById[QuestionnaireIds.optionalCompatibility];
  }
}
