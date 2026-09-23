import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileUnlockGrant {
  const ProfileUnlockGrant({
    required this.id,
    required this.userId,
    required this.matchId,
    required this.candidateUserId,
    required this.pairKey,
    required this.weekKey,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String matchId;
  final String candidateUserId;
  final String pairKey;
  final String weekKey;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'matchId': matchId,
      'candidateUserId': candidateUserId,
      'pairKey': pairKey,
      'weekKey': weekKey,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class ConversationActivationGrant {
  const ConversationActivationGrant({
    required this.id,
    required this.userId,
    required this.matchId,
    required this.conversationId,
    required this.pairKey,
    required this.weekKey,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String matchId;
  final String conversationId;
  final String pairKey;
  final String weekKey;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'matchId': matchId,
      'conversationId': conversationId,
      'pairKey': pairKey,
      'weekKey': weekKey,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
