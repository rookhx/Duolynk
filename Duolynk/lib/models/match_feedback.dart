import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchFeedbackReason {
  differentThings,
  lifestylesDidntFit,
  personalitiesDidntClick,
  communicationDidntFeelRight,
  distanceWasIssue,
  notEnoughSharedInterests,
  attractionWasntThere,
  timingWasntRight,
  metButNotMatch,
  preferNotToSay,
}

extension MatchFeedbackReasonLabel on MatchFeedbackReason {
  String get label {
    return switch (this) {
      MatchFeedbackReason.differentThings => 'We wanted different things',
      MatchFeedbackReason.lifestylesDidntFit => "Our lifestyles didn't fit",
      MatchFeedbackReason.personalitiesDidntClick =>
        "Our personalities didn't click",
      MatchFeedbackReason.communicationDidntFeelRight =>
        "Communication didn't feel right",
      MatchFeedbackReason.distanceWasIssue => 'Distance was an issue',
      MatchFeedbackReason.notEnoughSharedInterests =>
        'Not enough shared interests',
      MatchFeedbackReason.attractionWasntThere => "Attraction wasn't there",
      MatchFeedbackReason.timingWasntRight => "Timing wasn't right",
      MatchFeedbackReason.metButNotMatch => "We met, but it wasn't a match",
      MatchFeedbackReason.preferNotToSay => 'Prefer not to say',
    };
  }
}

class MatchFeedback {
  const MatchFeedback({
    required this.feedbackId,
    required this.userId,
    required this.matchId,
    required this.pairKey,
    required this.reasons,
    required this.goodMatch,
    required this.metInPerson,
    required this.createdAt,
    this.categoryScores = const {},
    this.compatibilityAlgorithmVersion,
    this.questionnaireVersion,
  });

  final String feedbackId;
  final String userId;
  final String matchId;
  final String pairKey;
  final Set<MatchFeedbackReason> reasons;
  final bool goodMatch;
  final bool metInPerson;
  final DateTime createdAt;
  final Map<String, int> categoryScores;
  final int? compatibilityAlgorithmVersion;
  final int? questionnaireVersion;

  bool get hasLearningSignal {
    return goodMatch ||
        reasons.any(
          (reason) =>
              reason != MatchFeedbackReason.preferNotToSay &&
              reason != MatchFeedbackReason.timingWasntRight &&
              reason != MatchFeedbackReason.attractionWasntThere &&
              reason != MatchFeedbackReason.metButNotMatch,
        );
  }

  Map<String, dynamic> toMap() {
    return {
      'feedbackId': feedbackId,
      'userId': userId,
      'matchId': matchId,
      'pairKey': pairKey,
      'reasons': reasons.map((reason) => reason.name).toList()..sort(),
      'goodMatch': goodMatch,
      'metInPerson': metInPerson,
      'createdAt': Timestamp.fromDate(createdAt),
      'categoryScores': categoryScores,
      if (compatibilityAlgorithmVersion != null)
        'compatibilityAlgorithmVersion': compatibilityAlgorithmVersion,
      if (questionnaireVersion != null)
        'questionnaireVersion': questionnaireVersion,
    };
  }

  static MatchFeedback fromMap(String id, Map<String, dynamic> map) {
    return MatchFeedback(
      feedbackId: (map['feedbackId'] as String?) ?? id,
      userId: (map['userId'] as String?) ?? '',
      matchId: (map['matchId'] as String?) ?? '',
      pairKey: (map['pairKey'] as String?) ?? '',
      reasons: (map['reasons'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map(
            (name) => MatchFeedbackReason.values.firstWhere(
              (reason) => reason.name == name,
              orElse: () => MatchFeedbackReason.preferNotToSay,
            ),
          )
          .toSet(),
      goodMatch: map['goodMatch'] == true,
      metInPerson: map['metInPerson'] == true,
      createdAt:
          _readDate(map['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      categoryScores: _readIntMap(map['categoryScores']),
      compatibilityAlgorithmVersion: _readInt(
        map['compatibilityAlgorithmVersion'],
      ),
      questionnaireVersion: _readInt(map['questionnaireVersion']),
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return null;
  }

  static Map<String, int> _readIntMap(dynamic value) {
    if (value is! Map) {
      return const {};
    }
    final result = <String, int>{};
    value.forEach((key, raw) {
      if (key is String && raw is num) {
        result[key] = raw.round();
      }
    });
    return result;
  }
}
