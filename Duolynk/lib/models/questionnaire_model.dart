import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionnaireModel {
  const QuestionnaireModel({
    required this.id,
    required this.userId,
    required this.answers,
    required this.completedSteps,
    required this.totalSteps,
    required this.createdAt,
    required this.updatedAt,
    this.isComplete = false,
    this.questionnaireVersion = 1,
  });

  final String id;
  final String userId;
  final Map<String, dynamic> answers;
  final int completedSteps;
  final int totalSteps;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isComplete;
  final int questionnaireVersion;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'answers': answers,
      'completedSteps': completedSteps,
      'totalSteps': totalSteps,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isComplete': isComplete,
      'questionnaireVersion': questionnaireVersion,
    };
  }

  factory QuestionnaireModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime readDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return DateTime.now();
    }

    final rawAnswers = map['answers'];

    return QuestionnaireModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      answers: Map<String, dynamic>.from(
        rawAnswers is Map ? rawAnswers : const {},
      ),
      completedSteps: map['completedSteps'] as int? ?? 0,
      totalSteps: map['totalSteps'] as int? ?? 0,
      createdAt: readDate(map['createdAt']),
      updatedAt: readDate(map['updatedAt']),
      isComplete: map['isComplete'] as bool? ?? false,
      questionnaireVersion:
          map['questionnaireVersion'] as int? ??
          (rawAnswers is Map
              ? (rawAnswers['questionnaireVersion'] as int? ?? 1)
              : 1),
    );
  }
}
