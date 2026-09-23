import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/config/firestore_paths.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/match_feedback.dart';
import '../../../models/match_model.dart';
import '../../../models/personalized_matching_profile.dart';
import '../../../services/analytics/analytics_event_service.dart';
import '../../../services/firebase/firebase_auth_service.dart';
import '../../../services/firebase/firestore_service.dart';
import '../../../services/matching/personalized_matching_service.dart';

final matchFeedbackRepositoryProvider = Provider<MatchFeedbackRepository>(
  (ref) => MatchFeedbackRepository(
    firestoreService: ref.watch(firestoreServiceProvider),
    authService: ref.watch(firebaseAuthServiceProvider),
    personalizationService: const PersonalizedMatchingService(),
  ),
);

class MatchFeedbackRepository {
  const MatchFeedbackRepository({
    required FirestoreService firestoreService,
    required FirebaseAuthService authService,
    required PersonalizedMatchingService personalizationService,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _personalizationService = personalizationService;

  static const String settingsId = 'personalized_matching';
  static const String profileId = 'personalized_matching_profile';

  final FirestoreService _firestoreService;
  final FirebaseAuthService _authService;
  final PersonalizedMatchingService _personalizationService;

  Future<PersonalizedMatchingSettings> fetchSettings() async {
    if (!AppEnvironment.firebaseEnabled) {
      return const PersonalizedMatchingSettings();
    }
    final userId = _authService.currentUserId;
    if (userId == null) {
      return const PersonalizedMatchingSettings();
    }
    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.userSetting(userId, settingsId),
    );
    return PersonalizedMatchingSettings.fromMap(snapshot.data());
  }

  Future<PersonalizedMatchingProfile> fetchProfileForUser(String userId) async {
    if (!AppEnvironment.firebaseEnabled) {
      return PersonalizedMatchingProfile.baseline(userId);
    }
    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.userSetting(userId, profileId),
    );
    return PersonalizedMatchingProfile.fromMap(userId, snapshot.data());
  }

  Future<void> setPersonalizedMatchingEnabled(bool enabled) async {
    if (!AppEnvironment.firebaseEnabled) {
      return;
    }
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw StateError('A signed-in user is required to update settings.');
    }
    await _firestoreService.setDocument(
      FirestorePaths.userSetting(userId, settingsId),
      {
        'enabled': enabled,
        'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
      },
    );
    await rebuildProfile(userId: userId);
    await const AnalyticsEventService().track(
      enabled
          ? 'personalized_matching_enabled'
          : 'personalized_matching_disabled',
    );
  }

  Future<void> resetPersonalizedMatching() async {
    if (!AppEnvironment.firebaseEnabled) {
      return;
    }
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw StateError('A signed-in user is required to reset settings.');
    }
    final settings = await fetchSettings();
    await _firestoreService.setDocument(
      FirestorePaths.userSetting(userId, profileId),
      PersonalizedMatchingProfile.baseline(
        userId,
        enabled: settings.enabled,
      ).copyWith(updatedAt: DateTime.now().toUtc()).toMap(),
    );
    await const AnalyticsEventService().track('personalized_matching_reset');
  }

  Future<void> submitFeedback({
    required MatchModel match,
    required Set<MatchFeedbackReason> reasons,
    required bool goodMatch,
    required bool metInPerson,
  }) async {
    if (!AppEnvironment.firebaseEnabled) {
      return;
    }
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw StateError('A signed-in user is required to submit feedback.');
    }

    final ref = _firestoreService
        .collection(FirestorePaths.userMatchFeedback(userId))
        .doc();
    final feedback = MatchFeedback(
      feedbackId: ref.id,
      userId: userId,
      matchId: match.id,
      pairKey: match.pairKey ?? match.id,
      reasons: reasons,
      goodMatch: goodMatch,
      metInPerson: metInPerson,
      createdAt: DateTime.now().toUtc(),
      categoryScores: match.categoryScores,
      compatibilityAlgorithmVersion: match.compatibilityAlgorithmVersion,
    );
    await _firestoreService.setDocument(
      FirestorePaths.userMatchFeedbackItem(userId, ref.id),
      feedback.toMap(),
      merge: false,
    );
    await rebuildProfile(userId: userId);
    await const AnalyticsEventService().track('match_feedback_submitted');
  }

  Future<void> skipFeedback() async {
    await const AnalyticsEventService().track('match_feedback_skipped');
  }

  Future<void> rebuildProfile({required String userId}) async {
    final settingsSnapshot = await _firestoreService.getDocument(
      FirestorePaths.userSetting(userId, settingsId),
    );
    final settings = PersonalizedMatchingSettings.fromMap(
      settingsSnapshot.data(),
    );
    final feedbackSnapshot = await _firestoreService.getCollection(
      FirestorePaths.userMatchFeedback(userId),
    );
    final feedback = feedbackSnapshot.docs
        .map((doc) => MatchFeedback.fromMap(doc.id, doc.data()))
        .toList();
    final profile = _personalizationService.buildProfile(
      userId: userId,
      enabled: settings.enabled,
      feedback: feedback,
    );
    await _firestoreService.setDocument(
      FirestorePaths.userSetting(userId, profileId),
      profile.toMap(),
    );
  }
}
