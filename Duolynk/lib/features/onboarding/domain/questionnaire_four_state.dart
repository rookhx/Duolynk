class QuestionnaireFourState {
  const QuestionnaireFourState({required this.answers, this.isSaving = false});

  final Map<String, String> answers;
  final bool isSaving;

  bool get isComplete =>
      answers.length == 7 && answers.values.every((v) => v.isNotEmpty);

  QuestionnaireFourState copyWith({
    Map<String, String>? answers,
    bool? isSaving,
  }) {
    return QuestionnaireFourState(
      answers: answers ?? this.answers,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
