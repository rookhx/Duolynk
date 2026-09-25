import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/config/firestore_paths.dart';
import '../../../core/config/storage_paths.dart';
import '../../../core/demo/demo_store.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/app_user.dart';
import '../../../models/match_model.dart';
import '../../../models/notification_preferences.dart';
import '../../../models/user_report.dart';
import '../../../services/analytics/analytics_event_service.dart';
import '../../../services/firebase/firebase_auth_service.dart';
import '../../../services/firebase/firebase_storage_service.dart';
import '../../../services/firebase/firestore_service.dart';
import '../../../services/matching/match_repeat_policy_service.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    firestoreService: ref.watch(firestoreServiceProvider),
    authService: ref.watch(firebaseAuthServiceProvider),
    storageService: ref.watch(firebaseStorageServiceProvider),
  ),
);

class ProfileRepository {
  const ProfileRepository({
    required FirestoreService firestoreService,
    required FirebaseAuthService authService,
    required FirebaseStorageService storageService,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _storageService = storageService;

  final FirestoreService _firestoreService;
  final FirebaseAuthService _authService;
  final FirebaseStorageService _storageService;

  Future<AppUser?> fetchProfile() async {
    if (!AppEnvironment.firebaseEnabled) {
      return DemoStore.user;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return null;
    }

    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.user(userId),
    );
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return AppUser.fromMap(snapshot.id, snapshot.data()!);
  }

  Stream<AppUser?> watchProfile() {
    if (!AppEnvironment.firebaseEnabled) {
      return Stream.value(DemoStore.user);
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return const Stream<AppUser?>.empty();
    }

    return _firestoreService.watchDocument(FirestorePaths.user(userId)).map((
      doc,
    ) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return AppUser.fromMap(doc.id, doc.data()!);
    });
  }

  Future<void> saveProfile(AppUser user) {
    if (!AppEnvironment.firebaseEnabled) {
      DemoStore.saveUser(
        user.copyWith(
          photoUrl: user.photoUrls.isNotEmpty
              ? user.photoUrls.first
              : user.photoUrl,
          isProfileComplete: user.datingProfileVersion == 0
              ? user.isProfileComplete
              : user.completionRatio >= 1 && user.requiredCompatibilityComplete,
          datingProfileComplete: user.datingProfileVersion == 0
              ? user.datingProfileComplete
              : user.completionRatio >= 1,
          updatedAt: DateTime.now(),
        ),
      );
      return Future.value();
    }

    final normalized = user.copyWith(
      photoUrl: user.photoUrls.isNotEmpty
          ? user.photoUrls.first
          : user.photoUrl,
      isProfileComplete: user.datingProfileVersion == 0
          ? user.isProfileComplete
          : user.completionRatio >= 1 && user.requiredCompatibilityComplete,
      datingProfileComplete: user.datingProfileVersion == 0
          ? user.datingProfileComplete
          : user.completionRatio >= 1,
      updatedAt: DateTime.now(),
    );
    return _firestoreService.setDocument(
      FirestorePaths.user(user.id),
      normalized.toEditableMap(),
    );
  }

  Future<List<String>> uploadProfilePhotos({
    required String userId,
    required List<Uint8List> images,
  }) async {
    if (!AppEnvironment.firebaseEnabled) {
      final existing = [...DemoStore.user.photoUrls];
      final generated = List<String>.generate(
        images.length,
        (index) => 'demo-photo-${existing.length + index + 1}',
      );
      final merged = [...existing, ...generated];
      DemoStore.saveUser(
        DemoStore.user.copyWith(
          photoUrl: merged.isNotEmpty ? merged.first : DemoStore.user.photoUrl,
          photoUrls: merged,
        ),
      );
      return generated;
    }

    final uploadedPaths = <String>[];

    for (var index = 0; index < images.length; index++) {
      final path = StoragePaths.profilePhoto(
        userId,
        'profile_${DateTime.now().millisecondsSinceEpoch}_$index.jpg',
      );
      final storagePath = await _storageService.uploadData(
        path: path,
        data: images[index],
        // storage.rules only accept uploads with an image/* content type.
        metadata: SettableMetadata(contentType: 'image/jpeg'),
        returnDownloadUrl: false,
      );
      uploadedPaths.add(storagePath);
    }

    await _firestoreService.setDocument(FirestorePaths.user(userId), {
      'photoUrl': uploadedPaths.isEmpty ? null : uploadedPaths.first,
      'photoUrls': uploadedPaths,
      // photoModerationStatuses is trusted (server/admin-owned) per
      // firestore.rules; clients must not write it. Missing entries are read
      // as approved by AppUser.fromMap.
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    return uploadedPaths;
  }

  Future<NotificationPreferences> fetchNotificationPreferences() async {
    if (!AppEnvironment.firebaseEnabled) {
      return DemoStore.notificationPreferences;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return const NotificationPreferences();
    }

    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.userSetting(userId, _notificationSettingsId),
    );
    final data = snapshot.data();
    if (data == null) {
      return const NotificationPreferences();
    }
    return NotificationPreferences.fromMap(data);
  }

  Future<void> saveNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    if (!AppEnvironment.firebaseEnabled) {
      DemoStore.notificationPreferences = preferences;
      return;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      throw StateError('A signed-in user is required to update settings.');
    }

    await _firestoreService.setDocument(
      FirestorePaths.userSetting(userId, _notificationSettingsId),
      preferences.toMap(),
    );
  }

  Future<void> pauseDating() async {
    final now = DateTime.now().toUtc();
    if (!AppEnvironment.firebaseEnabled) {
      DemoStore.saveUser(
        DemoStore.user.copyWith(
          datingStatus: DatingStatus.paused,
          datingPausedAt: now,
        ),
      );
      await const AnalyticsEventService().track('dating_paused');
      return;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      throw StateError('A signed-in user is required to pause dating.');
    }

    final pauseClosedReintroductionAt = const MatchRepeatPolicyService()
        .pausedClosureReintroductionAt(now);
    final batch = _firestoreService.batch();
    batch.set(
      _firestoreService.document(FirestorePaths.user(userId)),
      {
        'datingStatus': DatingStatus.paused.name,
        'datingPausedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );

    final snapshot = await _firestoreService
        .collection(FirestorePaths.matches)
        .where('participantIds', arrayContains: userId)
        .get();
    for (final doc in snapshot.docs) {
      final match = MatchModel.fromMap(doc.id, doc.data());
      if (match.status != MatchStatus.suggested &&
          match.status != MatchStatus.interested) {
        continue;
      }
      batch.set(doc.reference, {
        'status': MatchStatus.expired.name,
        'expiredAt': Timestamp.fromDate(now),
        'closureReason': MatchClosureReason.userPaused.name,
        'eligibleForReintroductionAt': Timestamp.fromDate(
          pauseClosedReintroductionAt,
        ),
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    }

    await batch.commit();
    await const AnalyticsEventService().track('dating_paused');
  }

  Future<void> resumeDating() async {
    final now = DateTime.now().toUtc();
    if (!AppEnvironment.firebaseEnabled) {
      DemoStore.saveUser(
        DemoStore.user.copyWith(
          datingStatus: DatingStatus.active,
          clearDatingPausedAt: true,
        ),
      );
      await const AnalyticsEventService().track('dating_resumed');
      return;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      throw StateError('A signed-in user is required to resume dating.');
    }

    await _firestoreService.setDocument(FirestorePaths.user(userId), {
      'datingStatus': DatingStatus.active.name,
      'datingPausedAt': FieldValue.delete(),
      'updatedAt': Timestamp.fromDate(now),
    });
    await const AnalyticsEventService().track('dating_resumed');
  }

  Future<Set<String>> fetchBlockedUserIds() async {
    if (!AppEnvironment.firebaseEnabled) {
      return DemoStore.blockedUserIds;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return const <String>{};
    }

    final snapshot = await _firestoreService.getCollection(
      FirestorePaths.userBlocks(userId),
    );
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  Future<void> blockUser({required String targetUserId, String? reason}) async {
    if (!AppEnvironment.firebaseEnabled) {
      DemoStore.blockedUserIds = {...DemoStore.blockedUserIds, targetUserId};
      return;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      throw StateError('A signed-in user is required to block another member.');
    }

    final now = DateTime.now().toUtc();
    final batch = _firestoreService.batch();
    batch.set(
      _firestoreService.document(
        FirestorePaths.userBlock(userId, targetUserId),
      ),
      {
        'blockedUserId': targetUserId,
        'reason': reason,
        'createdAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );

    batch.set(
      _firestoreService.document(
        FirestorePaths.match(_pairKey(userId, targetUserId)),
      ),
      {
        'userId': userId,
        'partnerId': targetUserId,
        'pairKey': _pairKey(userId, targetUserId),
        'participantIds': ([userId, targetUserId]..sort()),
        'status': MatchStatus.blocked.name,
        'createdAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(now),
        'blockedAt': Timestamp.fromDate(now),
        'blockedBy': userId,
        'updatedAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> reportUser({
    required String targetUserId,
    required ReportCategory category,
    String? details,
    required String source,
    String? matchId,
    String? pairKey,
  }) async {
    if (!AppEnvironment.firebaseEnabled) {
      return;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      throw StateError(
        'A signed-in user is required to report another member.',
      );
    }

    final reportRef = _firestoreService
        .collection(FirestorePaths.moderationReports)
        .doc();
    final report = UserReport(
      id: reportRef.id,
      reporterUserId: userId,
      targetUserId: targetUserId,
      category: category,
      details: details,
      createdAt: DateTime.now().toUtc(),
      source: source,
      matchId: matchId,
      pairKey: pairKey,
    );

    await _firestoreService.setDocument(
      FirestorePaths.moderationReport(report.id),
      report.toMap(),
      merge: false,
    );
  }

  Future<void> deleteCurrentAccount() async {
    if (!AppEnvironment.firebaseEnabled) {
      DemoStore.saveUser(
        DemoStore.user.copyWith(
          displayName: 'Demo User',
          bio: '',
          photoUrl: '',
          photoUrls: const [],
          interestedIn: const [],
          country: '',
          city: '',
          datingStatus: DatingStatus.active,
          clearDatingPausedAt: true,
          isProfileComplete: false,
          datingProfileComplete: false,
          requiredCompatibilityComplete: false,
          clearOnboardingStep: true,
        ),
      );
      return;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return;
    }

    await _deleteCollection(FirestorePaths.userQuestionnaires(userId));
    await _deleteCollection(FirestorePaths.userSubscriptions(userId));
    await _deleteCollection(FirestorePaths.userDevices(userId));
    await _deleteCollection(FirestorePaths.userSettings(userId));
    await _deleteCollection(FirestorePaths.userMatchFeedback(userId));
    await _deleteCollection(FirestorePaths.userBlocks(userId));
    await _deleteUserOwnedMatches(userId);
    await _deleteUserNotificationJobs(userId);
    await _firestoreService.deleteDocument(FirestorePaths.user(userId));
    await _authService.deleteCurrentUser();
  }

  Future<void> _deleteCollection(String path) async {
    final snapshot = await _firestoreService.getCollection(path);
    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestoreService.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> _deleteUserOwnedMatches(String userId) async {
    final snapshot = await _firestoreService
        .collection(FirestorePaths.matches)
        .where('userId', isEqualTo: userId)
        .get();
    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestoreService.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> _deleteUserNotificationJobs(String userId) async {
    final snapshot = await _firestoreService
        .collection(FirestorePaths.notificationJobs)
        .where('userId', isEqualTo: userId)
        .get();
    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestoreService.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  static const String _notificationSettingsId = 'notification_preferences';

  String _pairKey(String first, String second) {
    final sorted = [first, second]..sort();
    return '${sorted.first}_${sorted.last}';
  }
}
