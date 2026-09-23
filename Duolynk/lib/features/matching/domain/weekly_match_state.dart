import 'curated_match_suggestion.dart';

class WeeklyMatchState {
  const WeeklyMatchState({
    this.suggestion,
    this.recommendations = const [],
    this.isRefreshing = false,
  });

  final CuratedMatchSuggestion? suggestion;
  final List<CuratedMatchSuggestion> recommendations;
  final bool isRefreshing;

  WeeklyMatchState copyWith({
    CuratedMatchSuggestion? suggestion,
    List<CuratedMatchSuggestion>? recommendations,
    bool? isRefreshing,
  }) {
    return WeeklyMatchState(
      suggestion: suggestion ?? this.suggestion,
      recommendations: recommendations ?? this.recommendations,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
