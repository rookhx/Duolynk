import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseDeviceToken {
  const FirebaseDeviceToken({
    required this.id,
    required this.token,
    required this.platform,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String token;
  final String platform;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'token': token,
      'platform': platform,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
