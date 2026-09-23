class QuestionnaireOneState {
  const QuestionnaireOneState({
    required this.selectedInterests,
    this.isSaving = false,
  });

  final List<String> selectedInterests;
  final bool isSaving;

  QuestionnaireOneState copyWith({
    List<String>? selectedInterests,
    bool? isSaving,
  }) {
    return QuestionnaireOneState(
      selectedInterests: selectedInterests ?? this.selectedInterests,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
