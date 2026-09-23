enum CompatibilityQuestionCategory {
  interests,
  lifestyle,
  personality,
  relationshipValues,
  datingPreferences,
}

enum CompatibilityQuestionRole { eligibility, compatibility, informational }

enum CompatibilityScoringMethod {
  eligibilityOnly,
  ordinalSimilarity,
  compatibilityMatrix,
  multiSelectOverlap,
  informationalOnly,
}

class CompatibilityQuestionDefinition {
  const CompatibilityQuestionDefinition({
    required this.key,
    required this.question,
    required this.category,
    required this.role,
    required this.scoringMethod,
    this.required = true,
  });

  final String key;
  final String question;
  final CompatibilityQuestionCategory category;
  final CompatibilityQuestionRole role;
  final CompatibilityScoringMethod scoringMethod;
  final bool required;
}

class CompatibilityQuestionSchema {
  const CompatibilityQuestionSchema._();

  static const int questionnaireVersion = 2;

  static const requiredQuestions = [
    CompatibilityQuestionDefinition(
      key: 'selectedInterests',
      question: 'Things users enjoy',
      category: CompatibilityQuestionCategory.interests,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.multiSelectOverlap,
    ),
    CompatibilityQuestionDefinition(
      key: 'smoking',
      question: 'Smoking',
      category: CompatibilityQuestionCategory.lifestyle,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
    ),
    CompatibilityQuestionDefinition(
      key: 'drinking',
      question: 'Drinking',
      category: CompatibilityQuestionCategory.lifestyle,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
    ),
    CompatibilityQuestionDefinition(
      key: 'religionImportance',
      question: 'Religion importance',
      category: CompatibilityQuestionCategory.lifestyle,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
    ),
    CompatibilityQuestionDefinition(
      key: 'exerciseFrequency',
      question: 'Exercise frequency',
      category: CompatibilityQuestionCategory.lifestyle,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
    ),
    CompatibilityQuestionDefinition(
      key: 'dietPreference',
      question: 'Diet preference',
      category: CompatibilityQuestionCategory.lifestyle,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.compatibilityMatrix,
    ),
    CompatibilityQuestionDefinition(
      key: 'sleepingSchedule',
      question: 'Sleeping schedule',
      category: CompatibilityQuestionCategory.lifestyle,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.compatibilityMatrix,
    ),
    CompatibilityQuestionDefinition(
      key: 'socialLifestyle',
      question: 'Social lifestyle',
      category: CompatibilityQuestionCategory.lifestyle,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
    ),
    CompatibilityQuestionDefinition(
      key: 'introvertExtrovert',
      question: 'Introvert / extrovert',
      category: CompatibilityQuestionCategory.personality,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
    ),
    CompatibilityQuestionDefinition(
      key: 'planningVsSpontaneous',
      question: 'Planning vs spontaneous',
      category: CompatibilityQuestionCategory.personality,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
    ),
    CompatibilityQuestionDefinition(
      key: 'riskTaking',
      question: 'Risk taking',
      category: CompatibilityQuestionCategory.personality,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
    ),
    CompatibilityQuestionDefinition(
      key: 'communicationStyle',
      question: 'Communication style',
      category: CompatibilityQuestionCategory.personality,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.compatibilityMatrix,
    ),
    CompatibilityQuestionDefinition(
      key: 'communicationFrequency',
      question: 'When dating someone, how much communication feels right?',
      category: CompatibilityQuestionCategory.personality,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
    ),
    CompatibilityQuestionDefinition(
      key: 'conflictResolution',
      question: 'Conflict resolution',
      category: CompatibilityQuestionCategory.personality,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.compatibilityMatrix,
    ),
    CompatibilityQuestionDefinition(
      key: 'humorStyle',
      question: 'Humor style',
      category: CompatibilityQuestionCategory.personality,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.compatibilityMatrix,
    ),
    CompatibilityQuestionDefinition(
      key: 'marriage',
      question: 'Marriage',
      category: CompatibilityQuestionCategory.relationshipValues,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
    ),
    CompatibilityQuestionDefinition(
      key: 'longTermRelationship',
      question: 'Long-term relationship',
      category: CompatibilityQuestionCategory.relationshipValues,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
    ),
    CompatibilityQuestionDefinition(
      key: 'casualDating',
      question: 'Casual dating',
      category: CompatibilityQuestionCategory.relationshipValues,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
    ),
    CompatibilityQuestionDefinition(
      key: 'children',
      question: 'Children',
      category: CompatibilityQuestionCategory.relationshipValues,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.compatibilityMatrix,
    ),
    CompatibilityQuestionDefinition(
      key: 'familyImportance',
      question: 'Family importance',
      category: CompatibilityQuestionCategory.relationshipValues,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
    ),
    CompatibilityQuestionDefinition(
      key: 'careerPriority',
      question: 'Career priority',
      category: CompatibilityQuestionCategory.relationshipValues,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
    ),
    CompatibilityQuestionDefinition(
      key: 'livingTogether',
      question: 'How do you feel about living with a serious partner?',
      category: CompatibilityQuestionCategory.relationshipValues,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
    ),
    CompatibilityQuestionDefinition(
      key: 'ageRange',
      question: 'Age range',
      category: CompatibilityQuestionCategory.datingPreferences,
      role: CompatibilityQuestionRole.eligibility,
      scoringMethod: CompatibilityScoringMethod.eligibilityOnly,
    ),
    CompatibilityQuestionDefinition(
      key: 'distancePreference',
      question: 'Distance preference',
      category: CompatibilityQuestionCategory.datingPreferences,
      role: CompatibilityQuestionRole.eligibility,
      scoringMethod: CompatibilityScoringMethod.eligibilityOnly,
    ),
    CompatibilityQuestionDefinition(
      key: 'dealBreakers',
      question: 'Deal breakers',
      category: CompatibilityQuestionCategory.datingPreferences,
      role: CompatibilityQuestionRole.eligibility,
      scoringMethod: CompatibilityScoringMethod.eligibilityOnly,
    ),
    CompatibilityQuestionDefinition(
      key: 'relationshipExpectations',
      question: 'Relationship expectations',
      category: CompatibilityQuestionCategory.datingPreferences,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.compatibilityMatrix,
    ),
  ];

  static const optionalQuestions = [
    CompatibilityQuestionDefinition(
      key: 'affectionStyles',
      question: 'How do you most naturally show affection?',
      category: CompatibilityQuestionCategory.personality,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.multiSelectOverlap,
      required: false,
    ),
    CompatibilityQuestionDefinition(
      key: 'financialAttitude',
      question: 'Which best describes your approach to money?',
      category: CompatibilityQuestionCategory.lifestyle,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
      required: false,
    ),
    CompatibilityQuestionDefinition(
      key: 'pets',
      question: 'How do pets fit into your life?',
      category: CompatibilityQuestionCategory.lifestyle,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.compatibilityMatrix,
      required: false,
    ),
    CompatibilityQuestionDefinition(
      key: 'relocationOpenness',
      question: 'Would you consider relocating for the right relationship?',
      category: CompatibilityQuestionCategory.relationshipValues,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
      required: false,
    ),
    CompatibilityQuestionDefinition(
      key: 'culturalBackgroundImportance',
      question:
          'How important is sharing a similar cultural background with a partner?',
      category: CompatibilityQuestionCategory.relationshipValues,
      role: CompatibilityQuestionRole.compatibility,
      scoringMethod: CompatibilityScoringMethod.ordinalSimilarity,
      required: false,
    ),
    CompatibilityQuestionDefinition(
      key: 'politicalViewsImportance',
      question:
          'How important is having similar political views in a relationship?',
      category: CompatibilityQuestionCategory.relationshipValues,
      role: CompatibilityQuestionRole.informational,
      scoringMethod: CompatibilityScoringMethod.informationalOnly,
      required: false,
    ),
  ];
}
