import 'package:cloud_firestore/cloud_firestore.dart';

import 'compatibility_insight.dart';

enum ChatMessageType { text, image }

class ChatParticipantSnapshot {
  const ChatParticipantSnapshot({
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.country,
    this.age,
  });

  final String id;
  final String displayName;
  final String? photoUrl;
  final String? country;
  final int? age;

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'country': country,
      'age': age,
    };
  }

  factory ChatParticipantSnapshot.fromMap(String id, Map<String, dynamic> map) {
    return ChatParticipantSnapshot(
      id: id,
      displayName: map['displayName'] as String? ?? 'Duolynk Member',
      photoUrl: map['photoUrl'] as String?,
      country: map['country'] as String?,
      age: map['age'] as int?,
    );
  }
}

class ChatModel {
  const ChatModel({
    required this.id,
    required this.matchId,
    required this.pairKey,
    required this.memberIds,
    required this.memberSnapshots,
    required this.compatibilityScore,
    required this.compatibilityReasons,
    required this.lastMessage,
    required this.lastMessageType,
    required this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
    required this.lastReadAtByUser,
    required this.typingByUser,
    this.lastMessageSenderId,
    this.currentUserHasConversationAccess = false,
  });

  final String id;
  final String matchId;
  final String pairKey;
  final List<String> memberIds;
  final Map<String, ChatParticipantSnapshot> memberSnapshots;
  final int compatibilityScore;
  final List<CompatibilityInsight> compatibilityReasons;
  final String lastMessage;
  final ChatMessageType lastMessageType;
  final DateTime lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, DateTime> lastReadAtByUser;
  final Map<String, DateTime> typingByUser;
  final String? lastMessageSenderId;
  // Derived for the signed-in viewer from their private activation grant.
  // This value is intentionally not persisted on the shared chat document.
  final bool currentUserHasConversationAccess;

  Map<String, dynamic> toMap() {
    return {
      'matchId': matchId,
      'pairKey': pairKey,
      'memberIds': memberIds,
      'memberSnapshots': memberSnapshots.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'compatibilityScore': compatibilityScore,
      'compatibilityReasons': compatibilityReasons
          .map((reason) => reason.toMap())
          .toList(),
      'lastMessage': lastMessage,
      'lastMessageType': lastMessageType.name,
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastReadAtByUser': lastReadAtByUser.map(
        (key, value) => MapEntry(key, Timestamp.fromDate(value)),
      ),
      'typingByUser': typingByUser.map(
        (key, value) => MapEntry(key, Timestamp.fromDate(value)),
      ),
      'lastMessageSenderId': lastMessageSenderId,
    };
  }

  factory ChatModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime readDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return DateTime.now();
    }

    Map<String, DateTime> readDateMap(dynamic raw) {
      if (raw is! Map) {
        return const {};
      }

      return raw.map<String, DateTime>((key, value) {
        return MapEntry(key as String, readDate(value));
      });
    }

    final rawParticipants =
        map['memberSnapshots'] as Map<String, dynamic>? ?? const {};
    final rawReasons =
        map['compatibilityReasons'] as List<dynamic>? ?? const [];

    return ChatModel(
      id: id,
      matchId: map['matchId'] as String? ?? '',
      pairKey: map['pairKey'] as String? ?? '',
      memberIds: (map['memberIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      memberSnapshots: rawParticipants.map<String, ChatParticipantSnapshot>(
        (key, value) => MapEntry(
          key,
          ChatParticipantSnapshot.fromMap(
            key,
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      ),
      compatibilityScore: map['compatibilityScore'] as int? ?? 0,
      compatibilityReasons: rawReasons
          .whereType<Map>()
          .map(CompatibilityInsight.fromMap)
          .toList(),
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageType: ChatMessageType.values.firstWhere(
        (type) => type.name == map['lastMessageType'],
        orElse: () => ChatMessageType.text,
      ),
      lastMessageAt: readDate(map['lastMessageAt']),
      createdAt: readDate(map['createdAt']),
      updatedAt: readDate(map['updatedAt']),
      lastReadAtByUser: readDateMap(map['lastReadAtByUser']),
      typingByUser: readDateMap(map['typingByUser']),
      lastMessageSenderId: map['lastMessageSenderId'] as String?,
    );
  }

  ChatParticipantSnapshot? participantFor(String userId) {
    return memberSnapshots[userId];
  }
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.type,
    required this.createdAt,
    required this.readByUserIds,
    this.imageUrl,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final ChatMessageType type;
  final DateTime createdAt;
  final List<String> readByUserIds;
  final String? imageUrl;

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'readByUserIds': readByUserIds,
      'imageUrl': imageUrl,
    };
  }

  factory ChatMessageModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime readDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return DateTime.now();
    }

    return ChatMessageModel(
      id: id,
      chatId: map['chatId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      type: ChatMessageType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => ChatMessageType.text,
      ),
      createdAt: readDate(map['createdAt']),
      readByUserIds: (map['readByUserIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      imageUrl: map['imageUrl'] as String?,
    );
  }
}
