import 'compatibility_match_result.dart';
import 'match_model.dart';

class WeeklyMatchGenerationResult {
  const WeeklyMatchGenerationResult({
    required this.generatedMatches,
    required this.remainingQuota,
    required this.weekKey,
  });

  final List<MatchModel> generatedMatches;
  final int remainingQuota;
  final String weekKey;

  List<CompatibilityMatchResult> applyToRecommendations(
    List<CompatibilityMatchResult> recommendations,
  ) {
    if (generatedMatches.isEmpty) {
      return recommendations;
    }
    final partnerIds = generatedMatches.map((match) => match.partnerId).toSet();
    return recommendations
        .where(
          (recommendation) =>
              partnerIds.contains(recommendation.profile.user.id),
        )
        .toList();
  }
}
