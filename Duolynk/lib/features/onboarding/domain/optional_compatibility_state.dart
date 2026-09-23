class OptionalCompatibilityState {
  const OptionalCompatibilityState({
    required this.answers,
    this.isSaving = false,
  });

  final Map<String, dynamic> answers;
  final bool isSaving;

  int get completedCount {
    return answers.values.where((value) {
      if (value is String) {
        return value.trim().isNotEmpty;
      }
      if (value is List) {
        return value.isNotEmpty;
      }
      return value != null;
    }).length;
  }

  OptionalCompatibilityState copyWith({
    Map<String, dynamic>? answers,
    bool? isSaving,
  }) {
    return OptionalCompatibilityState(
      answers: answers ?? this.answers,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
