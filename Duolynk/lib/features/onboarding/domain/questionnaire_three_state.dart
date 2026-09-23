class QuestionnaireThreeState {
  const QuestionnaireThreeState({required this.answers, this.isSaving = false});

  final Map<String, String> answers;
  final bool isSaving;

  bool get isComplete =>
      answers.length == 7 && answers.values.every((v) => v.isNotEmpty);

  QuestionnaireThreeState copyWith({
    Map<String, String>? answers,
    bool? isSaving,
  }) {
    return QuestionnaireThreeState(
      answers: answers ?? this.answers,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
