class QuestionnaireTwoState {
  const QuestionnaireTwoState({required this.answers, this.isSaving = false});

  final Map<String, String> answers;
  final bool isSaving;

  bool get isComplete =>
      answers.length == 7 && answers.values.every((v) => v.isNotEmpty);

  QuestionnaireTwoState copyWith({
    Map<String, String>? answers,
    bool? isSaving,
  }) {
    return QuestionnaireTwoState(
      answers: answers ?? this.answers,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
