import '../../core/config/firestore_paths.dart';
import '../../models/app_user.dart';
import '../../models/duolynk_notification_type.dart';
import '../../models/match_model.dart';
import '../../models/notification_job.dart';
import '../../models/notification_preferences.dart';
import '../firebase/firestore_service.dart';

class MatchNotificationService {
  const MatchNotificationService({required FirestoreService firestoreService})
    : _firestoreService = firestoreService;

  final FirestoreService _firestoreService;

  Future<void> queueNewMatchNotification({
    required String userId,
    required MatchModel match,
  }) async {
    if (!await _canSendNormalDatingNotification(
      userId: userId,
      preference: (preferences) => preferences.newIntroductions,
    )) {
      return;
    }

    final jobRef = _firestoreService
        .collection(FirestorePaths.notificationJobs)
        .doc();
    final job = NotificationJob(
      id: jobRef.id,
      userId: userId,
      title: 'Duolynk found new people for you',
      body: 'Your curated candidates are ready.',
      type: DuolynkNotificationType.curatedIntroduction,
      createdAt: DateTime.now(),
      data: {'matchId': match.id, 'weekKey': match.weekKey, 'route': 'match'},
    );

    await _firestoreService.setDocument(
      FirestorePaths.notificationJob(job.id),
      job.toMap(),
      merge: false,
    );
  }

  Future<void> queueMutualMatchNotification({
    required String userId,
    required MatchModel match,
  }) async {
    if (!await _canSendNormalDatingNotification(
      userId: userId,
      preference: (preferences) => preferences.matchUpdates,
    )) {
      return;
    }

    final jobRef = _firestoreService
        .collection(FirestorePaths.notificationJobs)
        .doc();
    final job = NotificationJob(
      id: jobRef.id,
      userId: userId,
      title: "It's mutual!",
      body: 'You both want to connect.',
      type: DuolynkNotificationType.mutualMatch,
      createdAt: DateTime.now().toUtc(),
      data: {'matchId': match.id, 'pairKey': match.pairKey, 'route': 'match'},
    );

    await _firestoreService.setDocument(
      FirestorePaths.notificationJob(job.id),
      job.toMap(),
      merge: false,
    );
  }

  Future<void> queueIntroductionReminderIfEligible({
    required String userId,
    required MatchModel match,
    DateTime? now,
  }) async {
    final checkedAt = now ?? DateTime.now().toUtc();
    final user = await _fetchUser(userId);
    final preferences = await _fetchPreferences(userId);
    if (user == null ||
        !MatchNotificationService.isIntroductionReminderEligible(
          userId: userId,
          user: user,
          match: match,
          preferences: preferences,
          now: checkedAt,
        )) {
      return;
    }

    final jobId = 'introduction_reminder_${match.id}_$userId';
    final jobRef = _firestoreService.document(
      FirestorePaths.notificationJob(jobId),
    );
    await _firestoreService.runTransaction((transaction) async {
      final existing = await transaction.get(jobRef);
      if (existing.exists) {
        return;
      }

      final job = NotificationJob(
        id: jobId,
        userId: userId,
        title: 'Your introduction is waiting',
        body: 'Take a look before this introduction expires.',
        type: DuolynkNotificationType.introductionReminder,
        createdAt: checkedAt,
        dedupeKey: jobId,
        data: {'matchId': match.id, 'pairKey': match.pairKey, 'route': 'match'},
      );
      transaction.set(jobRef, job.toMap());
    });
  }

  static bool isIntroductionReminderEligible({
    required String userId,
    required AppUser user,
    required MatchModel match,
    required NotificationPreferences preferences,
    required DateTime now,
  }) {
    if (!preferences.pushEnabled || !preferences.reminders) {
      return false;
    }
    if (!user.canReceiveNewIntroductions) {
      return false;
    }
    if (!match.suggestedForUserIds.contains(userId)) {
      return false;
    }
    if (match.decisionFor(userId) != MatchParticipantDecision.pending) {
      return false;
    }
    if (match.status != MatchStatus.suggested &&
        match.status != MatchStatus.interested) {
      return false;
    }
    if (match.closureReason == MatchClosureReason.userPaused) {
      return false;
    }

    final remaining = match.expiresAt.toUtc().difference(now.toUtc());
    return remaining > Duration.zero && remaining <= const Duration(hours: 24);
  }

  Future<bool> _canSendNormalDatingNotification({
    required String userId,
    required bool Function(NotificationPreferences preferences) preference,
  }) async {
    final user = await _fetchUser(userId);
    if (user == null || !user.canUseDatingFeatures) {
      return false;
    }
    final preferences = await _fetchPreferences(userId);
    return preferences.pushEnabled && preference(preferences);
  }

  Future<AppUser?> _fetchUser(String userId) async {
    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.user(userId),
    );
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return AppUser.fromMap(userId, data);
  }

  Future<NotificationPreferences> _fetchPreferences(String userId) async {
    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.userSetting(userId, 'notification_preferences'),
    );
    final data = snapshot.data();
    return NotificationPreferences.fromMap(data ?? const {});
  }
}
