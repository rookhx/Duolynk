import 'package:cloud_firestore/cloud_firestore.dart';

import 'duolynk_notification_type.dart';

class NotificationJob {
  const NotificationJob({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.data,
    this.sent = false,
    this.dedupeKey,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final DuolynkNotificationType type;
  final DateTime createdAt;
  final Map<String, dynamic> data;
  final bool sent;
  final String? dedupeKey;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.id,
      'createdAt': Timestamp.fromDate(createdAt),
      'data': data,
      'sent': sent,
      'dedupeKey': dedupeKey,
    };
  }
}
