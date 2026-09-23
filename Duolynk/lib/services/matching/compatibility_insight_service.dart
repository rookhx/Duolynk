import '../../models/compatibility_insight.dart';
import '../../models/compatibility_match_result.dart';
import '../../models/compatibility_profile.dart';

class CompatibilityInsightService {
  const CompatibilityInsightService();

  static const int algorithmVersion = 2;

  List<CompatibilityInsight> buildInsights({
    required CompatibilityProfile currentUser,
    required CompatibilityProfile candidate,
    required MatchSearchScope locationScope,
    required Map<String, int> categoryScores,
    int maxInsights = 5,
  }) {
    final insights = <CompatibilityInsight>[
      ..._relationshipInsights(currentUser, candidate, categoryScores),
      ..._interestInsights(currentUser, candidate, categoryScores),
      ..._personalityInsights(currentUser, candidate, categoryScores),
      ..._lifestyleInsights(currentUser, candidate, categoryScores),
      ..._locationInsights(locationScope, categoryScores),
    ];

    insights.sort((a, b) {
      final priorityCompare = a.displayPriority.compareTo(b.displayPriority);
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      final strengthCompare = _strengthRank(
        b.strength,
      ).compareTo(_strengthRank(a.strength));
      if (strengthCompare != 0) {
        return strengthCompare;
      }
      return b.score.compareTo(a.score);
    });

    return insights.take(maxInsights).toList();
  }

  List<CompatibilityInsight> _relationshipInsights(
    CompatibilityProfile currentUser,
    CompatibilityProfile candidate,
    Map<String, int> categoryScores,
  ) {
    final score = categoryScores['relationshipGoals'] ?? 0;
    if (score < 65) {
      return const [];
    }

    final insights = <CompatibilityInsight>[
      CompatibilityInsight(
        label: 'Relationship Goals',
        category: 'relationshipGoals',
        type: 'relationship_alignment',
        title: 'Aligned relationship goals',
        score: score,
        description:
            'You share similar ideas about the kind of relationship you are looking for.',
        strength: score >= 80
            ? CompatibilityInsightStrength.strong
            : CompatibilityInsightStrength.moderate,
        displayPriority: 10,
        icon: 'favorite',
      ),
    ];

    final childrenA = _normalize(
      currentUser.relationshipGoalAnswers['children'],
    );
    final childrenB = _normalize(candidate.relationshipGoalAnswers['children']);
    final familyA = _normalize(
      currentUser.relationshipGoalAnswers['familyImportance'],
    );
    final familyB = _normalize(
      candidate.relationshipGoalAnswers['familyImportance'],
    );
    if (score >= 75 &&
        ((childrenA != null && childrenA == childrenB) ||
            (familyA != null && familyA == familyB))) {
      insights.add(
        CompatibilityInsight(
          label: 'Relationship Goals',
          category: 'relationshipGoals',
          type: 'family_outlook',
          title: 'Aligned family outlook',
          score: score,
          description:
              'Your compatibility profiles point to similar priorities around family and the future.',
          strength: CompatibilityInsightStrength.strong,
          displayPriority: 12,
          icon: 'family',
        ),
      );
    }

    return insights;
  }

  List<CompatibilityInsight> _interestInsights(
    CompatibilityProfile currentUser,
    CompatibilityProfile candidate,
    Map<String, int> categoryScores,
  ) {
    final shared = _sharedInterests(currentUser.interests, candidate.interests);
    if (shared.isEmpty) {
      return const [];
    }
    final score = categoryScores['interests'] ?? 0;
    final visible = shared.take(3).toList();
    final remainder = shared.length - visible.length;
    final description = remainder > 0
        ? 'You both enjoy ${_joinReadable(visible)} and $remainder more shared interests.'
        : 'You both enjoy ${_joinReadable(visible)}.';

    return [
      CompatibilityInsight(
        label: 'Interests',
        category: 'interests',
        type: 'shared_interests',
        title: 'Shared interests',
        score: score,
        description: description,
        strength: shared.length >= 3
            ? CompatibilityInsightStrength.strong
            : CompatibilityInsightStrength.moderate,
        displayPriority: 30,
        icon: 'interests',
        metadata: {'sharedInterestCount': shared.length},
      ),
    ];
  }

  List<CompatibilityInsight> _personalityInsights(
    CompatibilityProfile currentUser,
    CompatibilityProfile candidate,
    Map<String, int> categoryScores,
  ) {
    final score = categoryScores['personality'] ?? 0;
    if (score < 65) {
      return const [];
    }

    final frequencyA = _normalize(
      currentUser.personalityAnswers['communicationFrequency'],
    );
    final frequencyB = _normalize(
      candidate.personalityAnswers['communicationFrequency'],
    );
    if (score >= 70 && frequencyA != null && frequencyA == frequencyB) {
      return [
        CompatibilityInsight(
          label: 'Personality',
          category: 'personality',
          type: 'communication_rhythm',
          title: 'Similar communication rhythm',
          score: score,
          description: 'Your preferred level of communication is well aligned.',
          strength: score >= 80
              ? CompatibilityInsightStrength.strong
              : CompatibilityInsightStrength.moderate,
          displayPriority: 38,
          icon: 'message',
        ),
      ];
    }

    final affectionOverlap = _sharedListValues(
      currentUser.optionalAnswers['affectionStyles'],
      candidate.optionalAnswers['affectionStyles'],
    );
    if (score >= 70 && affectionOverlap.isNotEmpty) {
      return [
        CompatibilityInsight(
          label: 'Personality',
          category: 'personality',
          type: 'affection_fit',
          title: 'Compatible approach to affection',
          score: score,
          description:
              'You share similar ways of expressing care and connection.',
          strength: CompatibilityInsightStrength.moderate,
          displayPriority: 39,
          icon: 'favorite',
        ),
      ];
    }

    final planningA = _normalize(
      currentUser.personalityAnswers['planningVsSpontaneous'],
    );
    final planningB = _normalize(
      candidate.personalityAnswers['planningVsSpontaneous'],
    );
    if (score >= 75 && planningA != null && planningA == planningB) {
      return [
        CompatibilityInsight(
          label: 'Personality',
          category: 'personality',
          type: 'similar_pace',
          title: 'Similar pace',
          score: score,
          description:
              'Your answers suggest a compatible rhythm for planning, spontaneity and everyday decisions.',
          strength: CompatibilityInsightStrength.strong,
          displayPriority: 40,
          icon: 'personality',
        ),
      ];
    }

    final communicationA = _normalize(
      currentUser.personalityAnswers['communicationStyle'],
    );
    final communicationB = _normalize(
      candidate.personalityAnswers['communicationStyle'],
    );
    final conflictA = _normalize(
      currentUser.personalityAnswers['conflictResolution'],
    );
    final conflictB = _normalize(
      candidate.personalityAnswers['conflictResolution'],
    );
    final hasComplementaryDifference =
        (communicationA != null &&
            communicationB != null &&
            communicationA != communicationB) ||
        (conflictA != null && conflictB != null && conflictA != conflictB);
    if (hasComplementaryDifference) {
      return [
        CompatibilityInsight(
          label: 'Personality',
          category: 'personality',
          type: 'complementary_personality',
          title: 'A little different, in a good way',
          score: score,
          description:
              'Your personalities bring different strengths while still showing strong compatibility.',
          strength: CompatibilityInsightStrength.moderate,
          displayPriority: 42,
          icon: 'balance',
        ),
      ];
    }

    return [
      CompatibilityInsight(
        label: 'Personality',
        category: 'personality',
        type: 'personality_fit',
        title: 'Compatible personalities',
        score: score,
        description:
            'Your personality answers show a comfortable amount of overlap.',
        strength: CompatibilityInsightStrength.moderate,
        displayPriority: 44,
        icon: 'personality',
      ),
    ];
  }

  List<CompatibilityInsight> _lifestyleInsights(
    CompatibilityProfile currentUser,
    CompatibilityProfile candidate,
    Map<String, int> categoryScores,
  ) {
    final score = categoryScores['lifestyle'] ?? 0;
    if (score < 65) {
      return const [];
    }

    final comparableSafeKeys =
        const [
          'exerciseFrequency',
          'dietPreference',
          'sleepingSchedule',
          'socialLifestyle',
        ].where((key) {
          final first = _normalize(currentUser.lifestyleAnswers[key]);
          final second = _normalize(candidate.lifestyleAnswers[key]);
          return first != null && second != null;
        }).length;

    if (comparableSafeKeys == 0) {
      return const [];
    }

    return [
      CompatibilityInsight(
        label: 'Lifestyle',
        category: 'lifestyle',
        type: 'lifestyle_fit',
        title: 'Compatible lifestyles',
        score: score,
        description:
            'Your day-to-day lifestyle preferences show a meaningful amount of alignment.',
        strength: score >= 80
            ? CompatibilityInsightStrength.strong
            : CompatibilityInsightStrength.moderate,
        displayPriority: 50,
        icon: 'home',
      ),
    ];
  }

  List<CompatibilityInsight> _locationInsights(
    MatchSearchScope scope,
    Map<String, int> categoryScores,
  ) {
    final score = categoryScores['location'] ?? 0;
    if (score < 75) {
      return const [];
    }

    return [
      CompatibilityInsight(
        label: 'Location',
        category: 'location',
        type: 'location_fit',
        title: scope == MatchSearchScope.nearby
            ? 'Conveniently located'
            : 'Practical distance',
        score: score,
        description: scope == MatchSearchScope.nearby
            ? 'You appear to be close enough for dating to feel practical.'
            : 'Your locations fit within the distance settings used for this introduction.',
        strength: CompatibilityInsightStrength.informational,
        displayPriority: 70,
        icon: 'location',
      ),
    ];
  }

  List<String> _sharedInterests(List<String> first, List<String> second) {
    final firstByNormalized = {
      for (final interest in first)
        if (_normalize(interest) case final normalized?)
          normalized: _displayValue(interest),
    };
    final secondSet = second.map(_normalize).whereType<String>().toSet();
    final shared = firstByNormalized.entries
        .where((entry) => secondSet.contains(entry.key))
        .map((entry) => entry.value)
        .toList();
    shared.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return shared;
  }

  Set<String> _sharedListValues(dynamic first, dynamic second) {
    final firstSet = (first as List<dynamic>? ?? const [])
        .whereType<String>()
        .map(_normalize)
        .whereType<String>()
        .toSet();
    final secondSet = (second as List<dynamic>? ?? const [])
        .whereType<String>()
        .map(_normalize)
        .whereType<String>()
        .toSet();
    return firstSet.intersection(secondSet);
  }

  String _joinReadable(List<String> values) {
    if (values.length <= 1) {
      return values.join();
    }
    if (values.length == 2) {
      return '${values.first} and ${values.last}';
    }
    return '${values.take(values.length - 1).join(', ')} and ${values.last}';
  }

  String _displayValue(String value) => value.trim();

  String? _normalize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim().toLowerCase();
  }

  int _strengthRank(CompatibilityInsightStrength strength) {
    return switch (strength) {
      CompatibilityInsightStrength.strong => 3,
      CompatibilityInsightStrength.moderate => 2,
      CompatibilityInsightStrength.informational => 1,
    };
  }
}
