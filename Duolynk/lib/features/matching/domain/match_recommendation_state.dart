import '../../../models/compatibility_match_result.dart';

class MatchRecommendationState {
  const MatchRecommendationState({
    this.weeklyMatch,
    this.recommendations = const [],
    this.isRefreshing = false,
  });

  final CompatibilityMatchResult? weeklyMatch;
  final List<CompatibilityMatchResult> recommendations;
  final bool isRefreshing;
}
