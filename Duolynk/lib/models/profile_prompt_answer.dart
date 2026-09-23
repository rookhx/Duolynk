class ProfilePromptAnswer {
  const ProfilePromptAnswer({required this.promptId, required this.answer});

  final String promptId;
  final String answer;

  Map<String, dynamic> toMap() {
    return {'promptId': promptId, 'answer': answer};
  }

  factory ProfilePromptAnswer.fromMap(Map<dynamic, dynamic> map) {
    return ProfilePromptAnswer(
      promptId: map['promptId'] as String? ?? '',
      answer: map['answer'] as String? ?? '',
    );
  }
}
