import 'compatibility_insight.dart';
import 'compatibility_profile.dart';

enum MatchSearchScope { nearby, country, region, worldwide }

class CompatibilityMatchResult {
  const CompatibilityMatchResult({
    required this.profile,
    required this.compatibilityScore,
    required this.scope,
    required this.insights,
    required this.categoryScores,
    this.categoryDataCompleteness = const {},
    this.dataCompleteness = 0,
    this.strongestCategories = const [],
    this.weakerCategories = const [],
    this.algorithmVersion = 1,
    this.personalizedRankingScore,
  });

  final CompatibilityProfile profile;
  final int compatibilityScore;
  final MatchSearchScope scope;
  final List<CompatibilityInsight> insights;
  final Map<String, int> categoryScores;
  final Map<String, double> categoryDataCompleteness;
  final double dataCompleteness;
  final List<String> strongestCategories;
  final List<String> weakerCategories;
  final int algorithmVersion;
  final double? personalizedRankingScore;

  CompatibilityMatchResult copyWith({
    CompatibilityProfile? profile,
    int? compatibilityScore,
    MatchSearchScope? scope,
    List<CompatibilityInsight>? insights,
    Map<String, int>? categoryScores,
    Map<String, double>? categoryDataCompleteness,
    double? dataCompleteness,
    List<String>? strongestCategories,
    List<String>? weakerCategories,
    int? algorithmVersion,
    double? personalizedRankingScore,
  }) {
    return CompatibilityMatchResult(
      profile: profile ?? this.profile,
      compatibilityScore: compatibilityScore ?? this.compatibilityScore,
      scope: scope ?? this.scope,
      insights: insights ?? this.insights,
      categoryScores: categoryScores ?? this.categoryScores,
      categoryDataCompleteness:
          categoryDataCompleteness ?? this.categoryDataCompleteness,
      dataCompleteness: dataCompleteness ?? this.dataCompleteness,
      strongestCategories: strongestCategories ?? this.strongestCategories,
      weakerCategories: weakerCategories ?? this.weakerCategories,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
      personalizedRankingScore:
          personalizedRankingScore ?? this.personalizedRankingScore,
    );
  }
}
