import 'package:cloud_firestore/cloud_firestore.dart';

import 'compatibility_insight.dart';

enum MatchStatus {
  pending,
  suggested,
  interested,
  mutual,
  active,
  passed,
  expired,
  unmatched,
  blocked,
  archived,
}

enum MatchParticipantDecision { pending, interested, passed }

enum MatchClosureReason { userPaused }

class MatchModel {
  const MatchModel({
    required this.id,
    required this.userId,
    required this.partnerId,
    required this.compatibilityScore,
    required this.status,
    required this.compatibilityReasons,
    required this.createdAt,
    required this.expiresAt,
    this.categoryScores = const {},
    this.categoryDataCompleteness = const {},
    this.dataCompleteness = 0,
    this.compatibilityAlgorithmVersion = 1,
    this.chatId,
    this.searchScope,
    this.pairKey,
    this.weekKey,
    this.generatedForTier,
    this.generatedBySystem = false,
    this.notifiedAt,
    this.participantIds = const [],
    this.suggestedForUserIds = const [],
    this.participantDecisions = const {},
    this.participantDecisionAt = const {},
    this.mutualAt,
    this.passedAt,
    this.expiredAt,
    this.unmatchedAt,
    this.unmatchedBy,
    this.blockedAt,
    this.blockedBy,
    this.closureReason,
    this.eligibleForReintroductionAt,
  });

  final String id;
  final String userId;
  final String partnerId;
  final int compatibilityScore;
  final MatchStatus status;
  final List<CompatibilityInsight> compatibilityReasons;
  final Map<String, int> categoryScores;
  final Map<String, double> categoryDataCompleteness;
  final double dataCompleteness;
  final int compatibilityAlgorithmVersion;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? chatId;
  final String? searchScope;
  final String? pairKey;
  final String? weekKey;
  final String? generatedForTier;
  final bool generatedBySystem;
  final DateTime? notifiedAt;
  final List<String> participantIds;
  final List<String> suggestedForUserIds;
  final Map<String, MatchParticipantDecision> participantDecisions;
  final Map<String, DateTime> participantDecisionAt;
  final DateTime? mutualAt;
  final DateTime? passedAt;
  final DateTime? expiredAt;
  final DateTime? unmatchedAt;
  final String? unmatchedBy;
  final DateTime? blockedAt;
  final String? blockedBy;
  final MatchClosureReason? closureReason;
  final DateTime? eligibleForReintroductionAt;

  bool get isLegacyActiveMatch =>
      status == MatchStatus.active && participantIds.isEmpty;

  bool get isConversationEligible =>
      status == MatchStatus.mutual || status == MatchStatus.active;

  MatchParticipantDecision decisionFor(String userId) =>
      participantDecisions[userId] ?? MatchParticipantDecision.pending;

  String partnerIdFor(String userId) {
    if (participantIds.length >= 2 && participantIds.contains(userId)) {
      return participantIds.firstWhere((id) => id != userId);
    }
    return userId == this.userId ? partnerId : this.userId;
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'partnerId': partnerId,
      'compatibilityScore': compatibilityScore,
      'status': status.name,
      'compatibilityReasons': compatibilityReasons
          .map((reason) => reason.toMap())
          .toList(),
      'categoryScores': categoryScores,
      'categoryDataCompleteness': categoryDataCompleteness,
      'dataCompleteness': dataCompleteness,
      'compatibilityAlgorithmVersion': compatibilityAlgorithmVersion,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'chatId': chatId,
      'searchScope': searchScope,
      'pairKey': pairKey,
      'weekKey': weekKey,
      'generatedForTier': generatedForTier,
      'generatedBySystem': generatedBySystem,
      'notifiedAt': notifiedAt == null ? null : Timestamp.fromDate(notifiedAt!),
      'participantIds': participantIds,
      'suggestedForUserIds': suggestedForUserIds,
      'participantDecisions': participantDecisions.map(
        (userId, decision) => MapEntry(userId, decision.name),
      ),
      'participantDecisionAt': participantDecisionAt.map(
        (userId, date) => MapEntry(userId, Timestamp.fromDate(date)),
      ),
      'mutualAt': mutualAt == null ? null : Timestamp.fromDate(mutualAt!),
      'passedAt': passedAt == null ? null : Timestamp.fromDate(passedAt!),
      'expiredAt': expiredAt == null ? null : Timestamp.fromDate(expiredAt!),
      'unmatchedAt': unmatchedAt == null
          ? null
          : Timestamp.fromDate(unmatchedAt!),
      'unmatchedBy': unmatchedBy,
      'blockedAt': blockedAt == null ? null : Timestamp.fromDate(blockedAt!),
      'blockedBy': blockedBy,
      'closureReason': closureReason?.name,
      'eligibleForReintroductionAt': eligibleForReintroductionAt == null
          ? null
          : Timestamp.fromDate(eligibleForReintroductionAt!),
    };
  }

  factory MatchModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime readDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return DateTime.now();
    }

    final rawReasons =
        map['compatibilityReasons'] as List<dynamic>? ?? const [];

    DateTime? readNullableDate(dynamic value) {
      if (value == null) {
        return null;
      }
      return readDate(value);
    }

    List<String> readStringList(dynamic value) {
      return (value as List<dynamic>? ?? const []).whereType<String>().toList();
    }

    Map<String, MatchParticipantDecision> readDecisions(dynamic value) {
      if (value is! Map) {
        return const {};
      }
      return value.map<String, MatchParticipantDecision>((key, rawDecision) {
        return MapEntry(
          key as String,
          MatchParticipantDecision.values.firstWhere(
            (decision) => decision.name == rawDecision,
            orElse: () => MatchParticipantDecision.pending,
          ),
        );
      });
    }

    Map<String, DateTime> readDateMap(dynamic value) {
      if (value is! Map) {
        return const {};
      }
      return value.map<String, DateTime>((key, rawDate) {
        return MapEntry(key as String, readDate(rawDate));
      });
    }

    Map<String, int> readIntMap(dynamic value) {
      if (value is! Map) {
        return const {};
      }
      return value.map<String, int>(
        (key, rawValue) =>
            MapEntry(key as String, rawValue is num ? rawValue.round() : 0),
      );
    }

    Map<String, double> readDoubleMap(dynamic value) {
      if (value is! Map) {
        return const {};
      }
      return value.map<String, double>(
        (key, rawValue) =>
            MapEntry(key as String, rawValue is num ? rawValue.toDouble() : 0),
      );
    }

    MatchClosureReason? readClosureReason(dynamic value) {
      if (value is! String) {
        return null;
      }
      for (final reason in MatchClosureReason.values) {
        if (reason.name == value) {
          return reason;
        }
      }
      return null;
    }

    return MatchModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      partnerId: map['partnerId'] as String? ?? '',
      compatibilityScore: map['compatibilityScore'] as int? ?? 0,
      status: MatchStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => MatchStatus.pending,
      ),
      compatibilityReasons: rawReasons
          .whereType<Map>()
          .map(CompatibilityInsight.fromMap)
          .toList(),
      categoryScores: readIntMap(map['categoryScores']),
      categoryDataCompleteness: readDoubleMap(map['categoryDataCompleteness']),
      dataCompleteness: (map['dataCompleteness'] as num?)?.toDouble() ?? 0,
      compatibilityAlgorithmVersion:
          map['compatibilityAlgorithmVersion'] as int? ?? 1,
      createdAt: readDate(map['createdAt']),
      expiresAt: readDate(map['expiresAt']),
      chatId: map['chatId'] as String?,
      searchScope: map['searchScope'] as String?,
      pairKey: map['pairKey'] as String?,
      weekKey: map['weekKey'] as String?,
      generatedForTier: map['generatedForTier'] as String?,
      generatedBySystem: map['generatedBySystem'] as bool? ?? false,
      notifiedAt: readNullableDate(map['notifiedAt']),
      participantIds: readStringList(map['participantIds']),
      suggestedForUserIds: readStringList(map['suggestedForUserIds']),
      participantDecisions: readDecisions(map['participantDecisions']),
      participantDecisionAt: readDateMap(map['participantDecisionAt']),
      mutualAt: readNullableDate(map['mutualAt']),
      passedAt: readNullableDate(map['passedAt']),
      expiredAt: readNullableDate(map['expiredAt']),
      unmatchedAt: readNullableDate(map['unmatchedAt']),
      unmatchedBy: map['unmatchedBy'] as String?,
      blockedAt: readNullableDate(map['blockedAt']),
      blockedBy: map['blockedBy'] as String?,
      closureReason: readClosureReason(map['closureReason']),
      eligibleForReintroductionAt: readNullableDate(
        map['eligibleForReintroductionAt'],
      ),
    );
  }
}
