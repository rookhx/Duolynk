import 'dart:math' as math;

import '../../core/config/country_regions.dart';
import '../../models/compatibility_match_result.dart';
import '../../models/compatibility_profile.dart';
import 'compatibility_insight_service.dart';

class CompatibilityEngineService {
  const CompatibilityEngineService();

  static const int algorithmVersion =
      CompatibilityInsightService.algorithmVersion;

  static const double interestsWeight = 0.30;
  static const double lifestyleWeight = 0.25;
  static const double relationshipGoalsWeight = 0.25;
  static const double personalityWeight = 0.15;
  static const double locationWeight = 0.05;

  List<CompatibilityMatchResult> rankCandidates({
    required CompatibilityProfile currentUser,
    required List<CompatibilityProfile> candidates,
    int limit = 10,
    bool priorityMatching = false,
  }) {
    final ranked =
        candidates
            .map(
              (candidate) => _scoreCandidate(
                currentUser,
                candidate,
                priorityMatching: priorityMatching,
              ),
            )
            .toList()
          ..sort((a, b) {
            final scoreCompare = b.compatibilityScore.compareTo(
              a.compatibilityScore,
            );
            if (scoreCompare != 0 &&
                (b.compatibilityScore - a.compatibilityScore).abs() > 3) {
              return scoreCompare;
            }

            final confidenceCompare = b.dataCompleteness.compareTo(
              a.dataCompleteness,
            );
            if (confidenceCompare != 0) {
              return confidenceCompare;
            }
            if (scoreCompare != 0) {
              return scoreCompare;
            }
            if (priorityMatching) {
              final relationshipCompare =
                  (b.categoryScores['relationshipGoals'] ?? 0).compareTo(
                    a.categoryScores['relationshipGoals'] ?? 0,
                  );
              if (relationshipCompare != 0) {
                return relationshipCompare;
              }

              final personalityCompare = (b.categoryScores['personality'] ?? 0)
                  .compareTo(a.categoryScores['personality'] ?? 0);
              if (personalityCompare != 0) {
                return personalityCompare;
              }
            }
            return a.scope.index.compareTo(b.scope.index);
          });

    return ranked.take(limit).toList();
  }

  CompatibilityMatchResult _scoreCandidate(
    CompatibilityProfile currentUser,
    CompatibilityProfile candidate, {
    required bool priorityMatching,
  }) {
    final interests = _scoreInterests(
      currentUser.interests,
      candidate.interests,
    );
    final currentLifestyleAnswers = {
      ...currentUser.lifestyleAnswers,
      ..._optionalStringAnswers(currentUser, const [
        'financialAttitude',
        'pets',
      ]),
    };
    final candidateLifestyleAnswers = {
      ...candidate.lifestyleAnswers,
      ..._optionalStringAnswers(candidate, const ['financialAttitude', 'pets']),
    };
    final currentPersonalityAnswers = {...currentUser.personalityAnswers};
    final candidatePersonalityAnswers = {...candidate.personalityAnswers};
    final lifestyle = _scoreAnswers(
      currentLifestyleAnswers,
      candidateLifestyleAnswers,
      expectedKeys: _lifestyleKeys,
      scorer: scoreLifestyleAnswer,
    );
    final relationshipGoals = _scoreRelationshipCategory(
      currentUser,
      candidate,
    );
    final personality = _scoreAnswers(
      currentPersonalityAnswers,
      candidatePersonalityAnswers,
      expectedKeys: _personalityKeys,
      scorer: scorePersonalityAnswer,
    );
    final affection = _scoreAffectionStyles(
      currentUser.optionalAnswers['affectionStyles'],
      candidate.optionalAnswers['affectionStyles'],
    );
    final personalityWithAffection = _combineScoreResults([
      personality,
      affection,
    ]);
    final location = _scoreLocation(currentUser, candidate);

    final weights = _weights(priorityMatching: priorityMatching);
    final categories = {
      'interests': interests,
      'lifestyle': lifestyle,
      'relationshipGoals': relationshipGoals,
      'personality': personalityWithAffection,
      'location': location.scoreResult,
    };

    var weightedTotal = 0.0;
    var activeWeightTotal = 0.0;
    var completenessTotal = 0.0;
    for (final entry in categories.entries) {
      final weight = weights[entry.key] ?? 0;
      completenessTotal += entry.value.completeness * weight;
      if (!entry.value.hasSignal) {
        continue;
      }
      weightedTotal += entry.value.score * 100 * weight;
      activeWeightTotal += weight;
    }

    final compatibilityScore = activeWeightTotal == 0
        ? 0
        : (weightedTotal / activeWeightTotal).round().clamp(0, 100);
    final categoryScores = categories.map(
      (key, value) => MapEntry(key, value.scorePercent),
    );
    final categoryCompleteness = categories.map(
      (key, value) => MapEntry(key, value.completeness),
    );

    final insights = const CompatibilityInsightService().buildInsights(
      currentUser: currentUser,
      candidate: candidate,
      locationScope: location.scope,
      categoryScores: categoryScores,
    );

    return CompatibilityMatchResult(
      profile: candidate,
      compatibilityScore: compatibilityScore,
      scope: location.scope,
      insights: insights,
      categoryScores: categoryScores,
      categoryDataCompleteness: categoryCompleteness,
      dataCompleteness: completenessTotal.clamp(0, 1),
      strongestCategories: _categoryNamesByScore(categoryScores, minScore: 75),
      weakerCategories: _categoryNamesByScore(
        categoryScores,
        maxScore: 55,
        requireCompleteness: categoryCompleteness,
      ),
      algorithmVersion: algorithmVersion,
    );
  }

  Map<String, double> _weights({required bool priorityMatching}) {
    if (!priorityMatching) {
      return const {
        'interests': interestsWeight,
        'lifestyle': lifestyleWeight,
        'relationshipGoals': relationshipGoalsWeight,
        'personality': personalityWeight,
        'location': locationWeight,
      };
    }
    return const {
      'interests': 0.30,
      'lifestyle': 0.26,
      'relationshipGoals': 0.28,
      'personality': 0.14,
      'location': 0.02,
    };
  }

  _ScoreResult _scoreInterests(List<String> first, List<String> second) {
    final firstSet = first.map(_normalize).whereType<String>().toSet();
    final secondSet = second.map(_normalize).whereType<String>().toSet();
    if (firstSet.isEmpty || secondSet.isEmpty) {
      return const _ScoreResult.noSignal(expectedCount: 1);
    }

    final overlap = firstSet.intersection(secondSet).length;
    final smallerList = math.min(firstSet.length, secondSet.length);
    final coverage = smallerList == 0 ? 0.0 : overlap / smallerList;
    final jaccard = overlap / firstSet.union(secondSet).length;
    final score = ((coverage * 0.7) + (jaccard * 0.3)).clamp(0.0, 1.0);
    return _ScoreResult(
      totalScore: score,
      comparableCount: 1,
      expectedCount: 1,
    );
  }

  _ScoreResult _scoreAnswers(
    Map<String, String> first,
    Map<String, String> second, {
    required List<String> expectedKeys,
    required double Function(String key, String first, String second) scorer,
  }) {
    var total = 0.0;
    var comparable = 0;
    for (final key in expectedKeys) {
      final firstAnswer = _normalize(first[key]);
      final secondAnswer = _normalize(second[key]);
      if (firstAnswer == null || secondAnswer == null) {
        continue;
      }
      total += scorer(key, firstAnswer, secondAnswer).clamp(0, 1);
      comparable++;
    }
    if (comparable == 0) {
      return _ScoreResult.noSignal(expectedCount: expectedKeys.length);
    }
    return _ScoreResult(
      totalScore: total,
      comparableCount: comparable,
      expectedCount: expectedKeys.length,
    );
  }

  _ScoreResult _scoreRelationshipCategory(
    CompatibilityProfile currentUser,
    CompatibilityProfile candidate,
  ) {
    final base = _scoreAnswers(
      {
        ...currentUser.relationshipGoalAnswers,
        ..._optionalStringAnswers(currentUser, const [
          'relocationOpenness',
          'culturalBackgroundImportance',
        ]),
      },
      {
        ...candidate.relationshipGoalAnswers,
        ..._optionalStringAnswers(candidate, const [
          'relocationOpenness',
          'culturalBackgroundImportance',
        ]),
      },
      expectedKeys: _relationshipGoalKeys,
      scorer: scoreRelationshipAnswer,
    );

    final firstExpectation = _normalize(
      currentUser.preferenceAnswers['relationshipExpectations'] as String?,
    );
    final secondExpectation = _normalize(
      candidate.preferenceAnswers['relationshipExpectations'] as String?,
    );
    if (firstExpectation == null || secondExpectation == null) {
      return _ScoreResult(
        totalScore: base.totalScore,
        comparableCount: base.comparableCount,
        expectedCount: _relationshipGoalKeys.length + 1,
      );
    }

    return _ScoreResult(
      totalScore:
          base.totalScore +
          scoreRelationshipExpectation(firstExpectation, secondExpectation),
      comparableCount: base.comparableCount + 1,
      expectedCount: _relationshipGoalKeys.length + 1,
    );
  }

  double scoreAffectionStyleOverlap(dynamic first, dynamic second) {
    final firstSet = _stringSet(first);
    final secondSet = _stringSet(second);
    if (firstSet.isEmpty || secondSet.isEmpty) {
      return 0;
    }
    final overlap = firstSet.intersection(secondSet).length;
    final smallerList = math.min(firstSet.length, secondSet.length);
    final coverage = smallerList == 0 ? 0.0 : overlap / smallerList;
    final jaccard = overlap / firstSet.union(secondSet).length;
    return ((coverage * 0.75) + (jaccard * 0.25)).clamp(0.0, 1.0);
  }

  double scorePersonalityAnswer(String key, String first, String second) {
    if (first == second) {
      return 1;
    }
    final ordinal = _personalityOrdinals[key];
    if (ordinal != null) {
      return scoreOrdinalSimilarity(ordinal, first, second);
    }
    return scoreMatrixAnswer(_personalityMatrices[key], first, second);
  }

  double scoreLifestyleAnswer(String key, String first, String second) {
    if (first == second) {
      return 1;
    }
    final ordinal = _lifestyleOrdinals[key];
    if (ordinal != null) {
      return scoreOrdinalSimilarity(ordinal, first, second);
    }
    return scoreMatrixAnswer(_lifestyleMatrices[key], first, second);
  }

  double scoreRelationshipAnswer(String key, String first, String second) {
    if (first == second) {
      return 1;
    }
    final ordinal = _relationshipOrdinals[key];
    if (ordinal != null) {
      return scoreOrdinalSimilarity(ordinal, first, second);
    }
    return scoreMatrixAnswer(_relationshipMatrices[key], first, second);
  }

  double scoreRelationshipExpectation(String first, String second) {
    if (first == second) {
      return 1;
    }
    return scoreMatrixAnswer(_relationshipExpectationMatrix, first, second);
  }

  _ScoreResult _scoreAffectionStyles(dynamic first, dynamic second) {
    final firstSet = _stringSet(first);
    final secondSet = _stringSet(second);
    if (firstSet.isEmpty || secondSet.isEmpty) {
      return const _ScoreResult.noSignal(expectedCount: 1);
    }
    return _ScoreResult(
      totalScore: scoreAffectionStyleOverlap(first, second),
      comparableCount: 1,
      expectedCount: 1,
    );
  }

  _ScoreResult _combineScoreResults(List<_ScoreResult> results) {
    final totalScore = results.fold<double>(
      0,
      (total, result) => total + result.totalScore,
    );
    final comparableCount = results.fold<int>(
      0,
      (total, result) => total + result.comparableCount,
    );
    final expectedCount = results.fold<int>(
      0,
      (total, result) => total + result.expectedCount,
    );
    if (comparableCount == 0) {
      return _ScoreResult.noSignal(expectedCount: expectedCount);
    }
    return _ScoreResult(
      totalScore: totalScore,
      comparableCount: comparableCount,
      expectedCount: expectedCount,
    );
  }

  double scoreOrdinalSimilarity(
    List<String> orderedAnswers,
    String first,
    String second,
  ) {
    final firstIndex = orderedAnswers.indexOf(first);
    final secondIndex = orderedAnswers.indexOf(second);
    if (firstIndex < 0 || secondIndex < 0) {
      return _neutralDifferentScore;
    }
    final distance = (firstIndex - secondIndex).abs();
    if (distance == 0) {
      return 1;
    }
    final maxDistance = math.max(1, orderedAnswers.length - 1);
    final normalizedDistance = distance / maxDistance;
    return (1 - (normalizedDistance * 0.8)).clamp(0.2, 1);
  }

  double scoreMatrixAnswer(
    Map<String, Map<String, double>>? matrix,
    String first,
    String second,
  ) {
    if (first == second) {
      return 1;
    }
    return matrix?[first]?[second] ??
        matrix?[second]?[first] ??
        _neutralDifferentScore;
  }

  _LocationScore _scoreLocation(
    CompatibilityProfile currentUser,
    CompatibilityProfile candidate,
  ) {
    final current = currentUser.user;
    final other = candidate.user;
    final normalizedCurrentCountry = _normalize(current.country);
    final normalizedCandidateCountry = _normalize(other.country);
    final normalizedCurrentCity = _normalize(current.city);
    final normalizedCandidateCity = _normalize(other.city);

    if (current.latitude != null &&
        current.longitude != null &&
        other.latitude != null &&
        other.longitude != null) {
      final distanceKm = _haversineKm(
        current.latitude!,
        current.longitude!,
        other.latitude!,
        other.longitude!,
      );
      if (distanceKm <= 50) {
        return const _LocationScore(
          scoreResult: _ScoreResult(
            totalScore: 1,
            comparableCount: 1,
            expectedCount: 1,
          ),
          scope: MatchSearchScope.nearby,
          description: 'Located nearby.',
        );
      }
      if (normalizedCurrentCountry != null &&
          normalizedCurrentCountry == normalizedCandidateCountry) {
        return const _LocationScore(
          scoreResult: _ScoreResult(
            totalScore: 0.78,
            comparableCount: 1,
            expectedCount: 1,
          ),
          scope: MatchSearchScope.country,
          description: 'Based in the same country.',
        );
      }
    }

    if (normalizedCurrentCity != null &&
        normalizedCandidateCity != null &&
        normalizedCurrentCountry == normalizedCandidateCountry &&
        normalizedCurrentCity == normalizedCandidateCity) {
      return const _LocationScore(
        scoreResult: _ScoreResult(
          totalScore: 1,
          comparableCount: 1,
          expectedCount: 1,
        ),
        scope: MatchSearchScope.nearby,
        description: 'Located nearby in the same city.',
      );
    }

    if (normalizedCurrentCountry != null &&
        normalizedCurrentCountry == normalizedCandidateCountry) {
      return const _LocationScore(
        scoreResult: _ScoreResult(
          totalScore: 0.78,
          comparableCount: 1,
          expectedCount: 1,
        ),
        scope: MatchSearchScope.country,
        description: 'Based in the same country.',
      );
    }

    final currentRegion = CountryRegions.regionFor(current.country);
    final candidateRegion = CountryRegions.regionFor(other.country);
    if (currentRegion != null &&
        candidateRegion != null &&
        currentRegion == candidateRegion) {
      return _LocationScore(
        scoreResult: const _ScoreResult(
          totalScore: 0.56,
          comparableCount: 1,
          expectedCount: 1,
        ),
        scope: MatchSearchScope.region,
        description: 'Located in the same region: $currentRegion.',
      );
    }

    if (normalizedCurrentCountry == null &&
        normalizedCandidateCountry == null) {
      return const _LocationScore(
        scoreResult: _ScoreResult.noSignal(expectedCount: 1),
        scope: MatchSearchScope.worldwide,
        description: 'Location data is incomplete for this comparison.',
      );
    }

    return const _LocationScore(
      scoreResult: _ScoreResult(
        totalScore: 0.30,
        comparableCount: 1,
        expectedCount: 1,
      ),
      scope: MatchSearchScope.worldwide,
      description: 'A worldwide match where distance is secondary.',
    );
  }

  List<String> _categoryNamesByScore(
    Map<String, int> categoryScores, {
    int? minScore,
    int? maxScore,
    Map<String, double> requireCompleteness = const {},
  }) {
    final entries = categoryScores.entries.where((entry) {
      if ((requireCompleteness[entry.key] ?? 1) == 0) {
        return false;
      }
      if (minScore != null && entry.value < minScore) {
        return false;
      }
      if (maxScore != null && entry.value > maxScore) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((entry) => entry.key).take(3).toList();
  }

  double _haversineKm(
    double firstLatitude,
    double firstLongitude,
    double secondLatitude,
    double secondLongitude,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _radians(secondLatitude - firstLatitude);
    final dLon = _radians(secondLongitude - firstLongitude);
    final lat1 = _radians(firstLatitude);
    final lat2 = _radians(secondLatitude);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  String? _normalize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim().toLowerCase();
  }

  Map<String, String> _optionalStringAnswers(
    CompatibilityProfile profile,
    List<String> keys,
  ) {
    final result = <String, String>{};
    for (final key in keys) {
      final value = profile.optionalAnswers[key];
      if (value is String && value.trim().isNotEmpty) {
        result[key] = value;
      }
    }
    return result;
  }

  Set<String> _stringSet(dynamic value) {
    return (value as List<dynamic>? ?? const [])
        .whereType<String>()
        .map(_normalize)
        .whereType<String>()
        .toSet();
  }

  static const double _neutralDifferentScore = 0.5;

  static const _lifestyleKeys = [
    'smoking',
    'drinking',
    'religionImportance',
    'exerciseFrequency',
    'dietPreference',
    'sleepingSchedule',
    'socialLifestyle',
    'financialAttitude',
    'pets',
  ];

  static const _personalityKeys = [
    'introvertExtrovert',
    'planningVsSpontaneous',
    'riskTaking',
    'communicationStyle',
    'communicationFrequency',
    'conflictResolution',
    'humorStyle',
  ];

  static const _relationshipGoalKeys = [
    'marriage',
    'longTermRelationship',
    'casualDating',
    'children',
    'familyImportance',
    'careerPriority',
    'livingTogether',
    'relocationOpenness',
    'culturalBackgroundImportance',
  ];

  static const _lifestyleOrdinals = {
    'smoking': [
      'never',
      'occasionally',
      'socially',
      'regularly',
      'prefer not to say',
    ],
    'drinking': ['never', 'rarely', 'socially', 'often', 'prefer not to say'],
    'religionImportance': [
      'not important',
      'somewhat important',
      'important',
      'very important',
    ],
    'exerciseFrequency': [
      'rarely',
      '1-2 times a week',
      '3-4 times a week',
      '5+ times a week',
    ],
    'socialLifestyle': [
      'homebody',
      'balanced',
      'social and outgoing',
      'very active socially',
    ],
    'financialAttitude': [
      'careful saver',
      'mostly save but enjoy spending',
      'balanced',
      'spend on experiences',
      'spontaneous spender',
    ],
  };

  static const _personalityOrdinals = {
    'introvertExtrovert': [
      'deep introvert',
      'mostly introvert',
      'balanced',
      'mostly extrovert',
      'high-energy extrovert',
    ],
    'planningVsSpontaneous': [
      'love a plan',
      'usually organized',
      'balanced',
      'spontaneous often',
      'go with the flow',
    ],
    'riskTaking': [
      'very cautious',
      'thoughtfully careful',
      'balanced',
      'comfortably adventurous',
      'big risk taker',
    ],
    'communicationFrequency': [
      'i like plenty of space',
      'a few meaningful check-ins',
      'regular communication throughout the day',
      'i love staying closely connected',
    ],
  };

  static const _relationshipOrdinals = {
    'marriage': [
      'definitely want it',
      'open to it',
      'unsure',
      'not a priority',
      'do not want it',
    ],
    'longTermRelationship': [
      'essential',
      'very important',
      'open to it',
      'not sure yet',
      'not looking for that',
    ],
    'casualDating': [
      'not interested',
      'open in the short term',
      'depends on the person',
      'comfortable with it',
      'prefer casual right now',
    ],
    'familyImportance': [
      'central to my life',
      'very important',
      'important',
      'somewhat important',
      'less important',
    ],
    'careerPriority': [
      'top priority right now',
      'very important',
      'balanced with personal life',
      'flexible',
      'personal life comes first',
    ],
    'livingTogether': [
      'only after deep commitment',
      'open when the relationship is serious',
      'comfortable if timing feels right',
      'prefer to keep separate homes',
    ],
    'relocationOpenness': [
      'no',
      'only locally',
      'within my country',
      'internationally',
      'open to possibilities',
    ],
    'culturalBackgroundImportance': [
      'not important',
      'somewhat important',
      'important',
      'very important',
    ],
  };

  // Diet is not purely ordinal. These values reward compatible restrictions
  // without treating every different diet as a major relationship conflict.
  static const _lifestyleMatrices = {
    'dietPreference': {
      'vegetarian': {'vegan': 0.75, 'pescatarian': 0.75, 'no preference': 0.7},
      'vegan': {'pescatarian': 0.55, 'no preference': 0.65},
      'pescatarian': {'no preference': 0.7},
      'halal': {'kosher': 0.75, 'no preference': 0.65, 'other': 0.55},
      'kosher': {'no preference': 0.65, 'other': 0.55},
      'other': {'no preference': 0.55},
    },
    'sleepingSchedule': {
      'early bird': {
        'balanced': 0.8,
        'depends on the week': 0.65,
        'night owl': 0.35,
      },
      'balanced': {'night owl': 0.8, 'depends on the week': 0.85},
      'night owl': {'depends on the week': 0.65},
    },
    'pets': {
      'have or love pets': {
        'would like pets': 0.85,
        'neutral': 0.65,
        'prefer not to live with pets': 0.25,
      },
      'would like pets': {
        'neutral': 0.75,
        'prefer not to live with pets': 0.35,
      },
      'neutral': {'prefer not to live with pets': 0.65},
    },
  };

  // These personality dimensions are stylistic rather than better/worse, so
  // matrices reward natural pairings while keeping most differences moderate.
  static const _personalityMatrices = {
    'communicationStyle': {
      'direct and clear': {
        'warm and reflective': 0.8,
        'deep and intentional': 0.75,
        'depends on the person': 0.65,
        'playful and light': 0.55,
      },
      'warm and reflective': {
        'deep and intentional': 0.85,
        'depends on the person': 0.7,
        'playful and light': 0.6,
      },
      'playful and light': {
        'depends on the person': 0.7,
        'deep and intentional': 0.55,
      },
      'deep and intentional': {'depends on the person': 0.65},
    },
    'conflictResolution': {
      'need space first': {
        'prefer calm reflection': 0.85,
        'work toward compromise': 0.7,
        'need emotional reassurance': 0.45,
        'talk it through quickly': 0.35,
      },
      'talk it through quickly': {
        'work toward compromise': 0.8,
        'need emotional reassurance': 0.7,
        'prefer calm reflection': 0.55,
      },
      'prefer calm reflection': {
        'work toward compromise': 0.8,
        'need emotional reassurance': 0.6,
      },
      'work toward compromise': {'need emotional reassurance': 0.75},
    },
    'humorStyle': {
      'dry and witty': {
        'sarcastic': 0.85,
        'observational': 0.8,
        'playful and goofy': 0.6,
        'warm and wholesome': 0.55,
      },
      'sarcastic': {
        'observational': 0.75,
        'playful and goofy': 0.65,
        'warm and wholesome': 0.45,
      },
      'playful and goofy': {'observational': 0.65, 'warm and wholesome': 0.8},
      'observational': {'warm and wholesome': 0.65},
    },
  };

  static const _relationshipMatrices = {
    'children': {
      'definitely want children': {
        'open to children': 0.85,
        'unsure': 0.55,
        'already have children': 0.75,
        'do not want children': 0.15,
      },
      'open to children': {
        'unsure': 0.75,
        'already have children': 0.8,
        'do not want children': 0.35,
      },
      'unsure': {'already have children': 0.55, 'do not want children': 0.55},
      'do not want children': {'already have children': 0.25},
    },
  };

  static const _relationshipExpectationMatrix = {
    'clear commitment early': {
      'strong long-term alignment': 0.9,
      'shared emotional maturity': 0.8,
      'consistent communication': 0.75,
      'take things slowly': 0.45,
    },
    'take things slowly': {
      'consistent communication': 0.75,
      'shared emotional maturity': 0.75,
      'strong long-term alignment': 0.6,
    },
    'consistent communication': {
      'shared emotional maturity': 0.85,
      'strong long-term alignment': 0.8,
    },
    'shared emotional maturity': {'strong long-term alignment': 0.85},
  };
}

class _ScoreResult {
  const _ScoreResult({
    required this.totalScore,
    required this.comparableCount,
    required this.expectedCount,
  });

  const _ScoreResult.noSignal({required this.expectedCount})
    : totalScore = 0,
      comparableCount = 0;

  final double totalScore;
  final int comparableCount;
  final int expectedCount;

  bool get hasSignal => comparableCount > 0;

  double get score => comparableCount == 0 ? 0 : totalScore / comparableCount;

  int get scorePercent => (score * 100).round().clamp(0, 100);

  double get completeness =>
      expectedCount == 0 ? 0 : (comparableCount / expectedCount).clamp(0, 1);
}

class _LocationScore {
  const _LocationScore({
    required this.scoreResult,
    required this.scope,
    required this.description,
  });

  final _ScoreResult scoreResult;
  final MatchSearchScope scope;
  final String description;
}
