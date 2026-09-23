class QuestionnaireFiveState {
  const QuestionnaireFiveState({
    required this.ageRange,
    required this.distancePreference,
    required this.dealBreakers,
    required this.relationshipExpectations,
    this.isSaving = false,
  });

  final String? ageRange;
  final String? distancePreference;
  final List<String> dealBreakers;
  final String? relationshipExpectations;
  final bool isSaving;

  bool get isComplete =>
      (ageRange?.isNotEmpty ?? false) &&
      (distancePreference?.isNotEmpty ?? false) &&
      dealBreakers.isNotEmpty &&
      (relationshipExpectations?.isNotEmpty ?? false);

  int get completedCount {
    var count = 0;
    if (ageRange?.isNotEmpty ?? false) count++;
    if (distancePreference?.isNotEmpty ?? false) count++;
    if (dealBreakers.isNotEmpty) count++;
    if (relationshipExpectations?.isNotEmpty ?? false) count++;
    return count;
  }

  QuestionnaireFiveState copyWith({
    String? ageRange,
    bool clearAgeRange = false,
    String? distancePreference,
    bool clearDistancePreference = false,
    List<String>? dealBreakers,
    String? relationshipExpectations,
    bool clearRelationshipExpectations = false,
    bool? isSaving,
  }) {
    return QuestionnaireFiveState(
      ageRange: clearAgeRange ? null : (ageRange ?? this.ageRange),
      distancePreference: clearDistancePreference
          ? null
          : (distancePreference ?? this.distancePreference),
      dealBreakers: dealBreakers ?? this.dealBreakers,
      relationshipExpectations: clearRelationshipExpectations
          ? null
          : (relationshipExpectations ?? this.relationshipExpectations),
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
