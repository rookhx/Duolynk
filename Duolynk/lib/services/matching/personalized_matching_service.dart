import '../../models/compatibility_match_result.dart';
import '../../models/match_feedback.dart';
import '../../models/personalized_matching_profile.dart';

class PersonalizedMatchingService {
  const PersonalizedMatchingService();

  static const int minimumFeedbackSignals = 3;
  static const double maxWeightAdjustment = 0.05;
  static const double maxRankingPointAdjustment = 5;

  static const Map<String, double> baseWeights = {
    'interests': 0.30,
    'lifestyle': 0.25,
    'relationshipGoals': 0.25,
    'personality': 0.15,
    'location': 0.05,
  };

  PersonalizedMatchingProfile buildProfile({
    required String userId,
    required bool enabled,
    required List<MatchFeedback> feedback,
    DateTime? now,
  }) {
    final checkedAt = now ?? DateTime.now().toUtc();
    final categorySignals = <String, double>{
      for (final category in baseWeights.keys) category: 0,
    };
    var signalCount = 0;

    for (final entry in feedback) {
      final decay = recencyWeight(entry.createdAt, checkedAt);
      var entryHadLearningSignal = false;

      for (final reason in entry.reasons) {
        final category = categoryForNegativeReason(reason);
        if (category == null) {
          continue;
        }
        categorySignals[category] = (categorySignals[category] ?? 0) + decay;
        entryHadLearningSignal = true;
      }

      if (entry.goodMatch) {
        final reinforced = strongestPositiveCategories(entry.categoryScores);
        for (final category in reinforced) {
          categorySignals[category] =
              (categorySignals[category] ?? 0) + (decay * 0.65);
        }
        entryHadLearningSignal =
            entryHadLearningSignal || reinforced.isNotEmpty;
      }

      if (entryHadLearningSignal) {
        signalCount++;
      }
    }

    if (signalCount < minimumFeedbackSignals) {
      return PersonalizedMatchingProfile(
        userId: userId,
        enabled: enabled,
        feedbackSignalCount: signalCount,
        categoryWeightAdjustments: const {},
        updatedAt: checkedAt,
      );
    }

    final totalSignal = categorySignals.values.fold<double>(
      0,
      (total, value) => total + value,
    );
    if (totalSignal <= 0) {
      return PersonalizedMatchingProfile(
        userId: userId,
        enabled: enabled,
        feedbackSignalCount: signalCount,
        categoryWeightAdjustments: const {},
        updatedAt: checkedAt,
      );
    }

    final adjustments = <String, double>{};
    for (final entry in categorySignals.entries) {
      if (entry.value <= 0) {
        continue;
      }
      adjustments[entry.key] = (entry.value / totalSignal * maxWeightAdjustment)
          .clamp(0, maxWeightAdjustment)
          .toDouble();
    }

    return PersonalizedMatchingProfile(
      userId: userId,
      enabled: enabled,
      feedbackSignalCount: signalCount,
      categoryWeightAdjustments: adjustments,
      updatedAt: checkedAt,
    );
  }

  String? categoryForNegativeReason(MatchFeedbackReason reason) {
    return switch (reason) {
      MatchFeedbackReason.differentThings => 'relationshipGoals',
      MatchFeedbackReason.lifestylesDidntFit => 'lifestyle',
      MatchFeedbackReason.personalitiesDidntClick => 'personality',
      MatchFeedbackReason.communicationDidntFeelRight => 'personality',
      MatchFeedbackReason.distanceWasIssue => 'location',
      MatchFeedbackReason.notEnoughSharedInterests => 'interests',
      MatchFeedbackReason.attractionWasntThere => null,
      MatchFeedbackReason.timingWasntRight => null,
      MatchFeedbackReason.metButNotMatch => null,
      MatchFeedbackReason.preferNotToSay => null,
    };
  }

  List<String> strongestPositiveCategories(Map<String, int> categoryScores) {
    final entries =
        categoryScores.entries
            .where((entry) => baseWeights.containsKey(entry.key))
            .where((entry) => entry.value >= 75)
            .toList()
          ..sort((a, b) {
            final scoreCompare = b.value.compareTo(a.value);
            if (scoreCompare != 0) {
              return scoreCompare;
            }
            return _categoryPriority(a.key).compareTo(_categoryPriority(b.key));
          });
    return entries.map((entry) => entry.key).take(2).toList();
  }

  double recencyWeight(DateTime feedbackAt, DateTime now) {
    final ageDays = now.toUtc().difference(feedbackAt.toUtc()).inDays;
    if (ageDays <= 90) {
      return 1;
    }
    if (ageDays <= 365) {
      return 0.6;
    }
    return 0.3;
  }

  double personalizedScoreFor(
    CompatibilityMatchResult result,
    PersonalizedMatchingProfile profile,
  ) {
    if (!profile.canPersonalize) {
      return result.compatibilityScore.toDouble();
    }

    final weights = effectiveWeights(profile);
    var weightedTotal = 0.0;
    var activeWeightTotal = 0.0;
    for (final entry in weights.entries) {
      final score = result.categoryScores[entry.key];
      if (score == null) {
        continue;
      }
      weightedTotal += score * entry.value;
      activeWeightTotal += entry.value;
    }
    if (activeWeightTotal <= 0) {
      return result.compatibilityScore.toDouble();
    }

    final weightedScore = weightedTotal / activeWeightTotal;
    final delta = (weightedScore - result.compatibilityScore).clamp(
      -maxRankingPointAdjustment,
      maxRankingPointAdjustment,
    );
    return (result.compatibilityScore + delta).clamp(0, 100).toDouble();
  }

  double balancedPairRankingScore({
    required CompatibilityMatchResult result,
    required PersonalizedMatchingProfile currentUserProfile,
    required PersonalizedMatchingProfile candidateProfile,
  }) {
    final currentScore = personalizedScoreFor(result, currentUserProfile);
    final candidateScore = personalizedScoreFor(result, candidateProfile);
    // Pair creation is two-sided, so each participant's learned preferences get
    // equal say. Missing/disabled profiles contribute the unmodified base score.
    return ((currentScore + candidateScore) / 2).clamp(0, 100).toDouble();
  }

  Map<String, double> effectiveWeights(PersonalizedMatchingProfile profile) {
    final weights = <String, double>{};
    for (final entry in baseWeights.entries) {
      final delta = (profile.categoryWeightAdjustments[entry.key] ?? 0).clamp(
        -maxWeightAdjustment,
        maxWeightAdjustment,
      );
      weights[entry.key] = (entry.value + delta).clamp(0.01, 1).toDouble();
    }

    final total = weights.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      return baseWeights;
    }
    return weights.map((key, value) => MapEntry(key, value / total));
  }

  int _categoryPriority(String category) {
    return switch (category) {
      'relationshipGoals' => 0,
      'lifestyle' => 1,
      'personality' => 2,
      'interests' => 3,
      'location' => 4,
      _ => 99,
    };
  }
}
