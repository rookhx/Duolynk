import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firestore rules protect trusted and private dating data', () {
    final rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('match /moderation_reports/{reportId}'));
    expect(rules, contains('allow read: if isPrivileged();'));
    expect(rules, contains('allow create, update, delete: if isPrivileged();'));
    expect(rules, contains('hasActivatedConversation(conversationId)'));
    expect(rules, contains('match /conversationActivations/{activationId}'));
    expect(rules, contains('match /profileUnlocks/{unlockId}'));
    expect(rules, contains('match /weeklyAccess/{weekKey}'));
    expect(rules, contains('match /entitlements/{userId}'));
    expect(rules, contains('match /protectedProfiles/{userId}'));
    expect(
      rules,
      contains('request.resource.data.senderId == request.auth.uid'),
    );
    expect(rules, contains('request.resource.data.createdAt == request.time'));
    expect(rules, contains('resource.data.senderId == request.auth.uid'));
    expect(rules, contains('match /notification_jobs/{jobId}'));
    expect(rules, contains('match /matchFeedback/{feedbackId}'));
    expect(rules, contains('match /publicProfiles/{userId}'));
    expect(rules, contains('moderationStatus'));
    expect(rules, contains('verificationStatus'));
  });

  test('Storage rules restrict uploads and protected chat attachments', () {
    final rules = File('storage.rules').readAsStringSync();

    expect(rules, contains('request.resource.size <= 8 * 1024 * 1024'));
    expect(rules, contains("request.resource.contentType.matches('image/.*')"));
    expect(rules, contains('match /users/{userId}/profile/{fileName}'));
    expect(rules, contains('canReadOriginalProfilePhoto(userId)'));
    expect(rules, contains('hasPremiumCandidateAccess'));
    expect(
      rules,
      contains(
        'match /conversations/{conversationId}/messages/{messageId}/{fileName}',
      ),
    );
    expect(rules, contains('hasActivatedConversation(conversationId)'));
    expect(rules, contains('match /verification/{userId}/{fileName}'));
  });

  test('Firebase config includes rules, indexes, and emulators', () {
    final firebaseJson = File('firebase.json').readAsStringSync();
    final indexes = File('firestore.indexes.json').readAsStringSync();

    expect(firebaseJson, contains('"rules": "firestore.rules"'));
    expect(firebaseJson, contains('"rules": "storage.rules"'));
    expect(firebaseJson, contains('"functions"'));
    expect(firebaseJson, contains('"firestore.indexes.json"'));
    expect(firebaseJson, contains('"emulators"'));
    expect(indexes, contains('"collectionGroup": "messages"'));
    expect(indexes, contains('"fieldPath": "senderId"'));
  });
}
