import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/config/firestore_paths.dart';
import '../../../core/config/questionnaire_ids.dart';
import '../../../core/demo/demo_store.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/app_user.dart';
import '../../../models/compatibility_match_result.dart';
import '../../../models/compatibility_profile.dart';
import '../../../models/match_model.dart';
import '../../../models/personalized_matching_profile.dart';
import '../../../services/access/trusted_access_repository.dart';
import '../../../services/analytics/analytics_event_service.dart';
import '../domain/curated_match_suggestion.dart';
import '../../../services/firebase/firebase_auth_service.dart';
import '../../../services/firebase/firestore_service.dart';
import '../../../services/matching/compatibility_engine_service.dart';
import '../../../services/matching/match_eligibility_service.dart';
import '../../../services/matching/match_repeat_policy_service.dart';
import '../../../services/matching/personalized_matching_service.dart';
import '../../../services/profile/dating_profile_service.dart';

final matchingRepositoryProvider = Provider<MatchingRepository>(
  (ref) => MatchingRepository(
    firestoreService: ref.watch(firestoreServiceProvider),
    authService: ref.watch(firebaseAuthServiceProvider),
    compatibilityEngine: const CompatibilityEngineService(),
    eligibilityService: const MatchEligibilityService(),
    repeatPolicyService: const MatchRepeatPolicyService(),
    personalizedMatchingService: const PersonalizedMatchingService(),
    trustedAccessRepository: ref.watch(trustedAccessRepositoryProvider),
  ),
);

class MatchResponseResult {
  const MatchResponseResult({required this.match, this.createdMutual = false});

  final MatchModel match;
  final bool createdMutual;
}

class MatchingRepository {
  const MatchingRepository({
    required FirestoreService firestoreService,
    required FirebaseAuthService authService,
    required CompatibilityEngineService compatibilityEngine,
    required MatchEligibilityService eligibilityService,
    required MatchRepeatPolicyService repeatPolicyService,
    required PersonalizedMatchingService personalizedMatchingService,
    required TrustedAccessRepository trustedAccessRepository,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _compatibilityEngine = compatibilityEngine,
       _eligibilityService = eligibilityService,
       _repeatPolicyService = repeatPolicyService,
       _personalizedMatchingService = personalizedMatchingService,
       _trustedAccessRepository = trustedAccessRepository;

  final FirestoreService _firestoreService;
  final FirebaseAuthService _authService;
  final CompatibilityEngineService _compatibilityEngine;
  final MatchEligibilityService _eligibilityService;
  final MatchRepeatPolicyService _repeatPolicyService;
  final PersonalizedMatchingService _personalizedMatchingService;
  final TrustedAccessRepository _trustedAccessRepository;

  Future<MatchModel?> fetchWeeklyMatch() async {
    if (!AppEnvironment.firebaseEnabled) {
      return DemoStore.blockedUserIds.contains(DemoStore.activeMatch.partnerId)
          ? null
          : DemoStore.activeMatch;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return null;
    }

    final query = await _firestoreService
        .collection(FirestorePaths.matches)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: MatchStatus.active.name)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    final document = query.docs.first;
    return MatchModel.fromMap(document.id, document.data());
  }

  Stream<List<MatchModel>> watchActiveMatches() {
    if (!AppEnvironment.firebaseEnabled) {
      final matches =
          DemoStore.blockedUserIds.contains(DemoStore.activeMatch.partnerId)
          ? const <MatchModel>[]
          : [DemoStore.activeMatch];
      return Stream.value(matches);
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return const Stream<List<MatchModel>>.empty();
    }

    return _firestoreService.collection(FirestorePaths.matches).snapshots().map(
      (snapshot) {
        return snapshot.docs
            .map((doc) => MatchModel.fromMap(doc.id, doc.data()))
            .where(
              (match) =>
                  (match.isLegacyActiveMatch &&
                      match.userId == userId &&
                      match.status == MatchStatus.active) ||
                  (match.participantIds.contains(userId) &&
                      match.isConversationEligible),
            )
            .toList();
      },
    );
  }

  Stream<List<MatchModel>> watchSuggestedMatches() {
    if (!AppEnvironment.firebaseEnabled) {
      return Stream.value([DemoStore.activeMatch]);
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return const Stream<List<MatchModel>>.empty();
    }

    return _firestoreService.collection(FirestorePaths.matches).snapshots().map(
      (snapshot) {
        return snapshot.docs
            .map((doc) => MatchModel.fromMap(doc.id, doc.data()))
            .where(
              (match) =>
                  match.suggestedForUserIds.contains(userId) &&
                  match.decisionFor(userId) ==
                      MatchParticipantDecision.pending &&
                  (match.status == MatchStatus.suggested ||
                      match.status == MatchStatus.interested),
            )
            .toList();
      },
    );
  }

  Future<List<MatchModel>> fetchMatchHistory({
    required String userId,
    int limit = 50,
  }) async {
    if (!AppEnvironment.firebaseEnabled) {
      return DemoStore.blockedUserIds.contains(DemoStore.activeMatch.partnerId)
          ? const []
          : [DemoStore.activeMatch];
    }

    final snapshot = await _firestoreService
        .collection(FirestorePaths.matches)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => MatchModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<MatchModel>> fetchGeneratedMatchesForWeek({
    required String userId,
    required String weekKey,
  }) async {
    if (!AppEnvironment.firebaseEnabled) {
      return DemoStore.activeMatch.weekKey == weekKey
          ? [DemoStore.activeMatch]
          : const [];
    }

    // firestore.rules only let a user read matches listing them in
    // participantIds, so the query must filter on that field; a query on
    // userId or suggestedForUserIds is rejected outright.
    final snapshot = await _firestoreService
        .collection(FirestorePaths.matches)
        .where('participantIds', arrayContains: userId)
        .where('weekKey', isEqualTo: weekKey)
        .where('generatedBySystem', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => MatchModel.fromMap(doc.id, doc.data()))
        .where(
          (match) =>
              match.userId == userId ||
              match.suggestedForUserIds.contains(userId),
        )
        .toList();
  }

  Future<bool> canCurrentUserReceiveNewIntroductions() async {
    if (!AppEnvironment.firebaseEnabled) {
      return DemoStore.user.canReceiveNewIntroductions;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return false;
    }

    final user = await _fetchUser(userId);
    return user?.canReceiveNewIntroductions ?? false;
  }

  Future<Set<String>> fetchHistoricalPairKeys({required String userId}) async {
    if (!AppEnvironment.firebaseEnabled) {
      return {
        if (DemoStore.activeMatch.pairKey != null)
          DemoStore.activeMatch.pairKey!,
      };
    }

    final legacySnapshot = await _firestoreService
        .collection(FirestorePaths.matches)
        .where('userId', isEqualTo: userId)
        .get();

    final canonicalSnapshot = await _firestoreService
        .collection(FirestorePaths.matches)
        .where('participantIds', arrayContains: userId)
        .get();

    return {
      ...legacySnapshot.docs
          .map((doc) => MatchModel.fromMap(doc.id, doc.data()).pairKey)
          .whereType<String>(),
      ...canonicalSnapshot.docs
          .map((doc) => MatchModel.fromMap(doc.id, doc.data()).pairKey)
          .whereType<String>(),
    };
  }

  Future<Set<String>> fetchExcludedPairKeysForRecommendation({
    required String userId,
    DateTime? now,
  }) async {
    if (!AppEnvironment.firebaseEnabled) {
      return {
        if (DemoStore.activeMatch.pairKey != null)
          DemoStore.activeMatch.pairKey!,
      };
    }

    final checkedAt = now ?? DateTime.now().toUtc();
    final legacySnapshot = await _firestoreService
        .collection(FirestorePaths.matches)
        .where('userId', isEqualTo: userId)
        .get();
    final canonicalSnapshot = await _firestoreService
        .collection(FirestorePaths.matches)
        .where('participantIds', arrayContains: userId)
        .get();

    final excluded = <String>{};
    for (final doc in [...legacySnapshot.docs, ...canonicalSnapshot.docs]) {
      final match = MatchModel.fromMap(doc.id, doc.data());
      final pairKey = match.pairKey;
      if (pairKey == null || pairKey.isEmpty) {
        continue;
      }
      if (_repeatPolicyService.excludesFromRecommendations(match, checkedAt)) {
        excluded.add(pairKey);
      }
    }
    return excluded;
  }

  Future<MatchModel> createOrUpdateSuggestedMatch({
    required String userId,
    required CompatibilityMatchResult recommendation,
    required String weekKey,
    required DateTime expiresAt,
    required String generatedForTier,
  }) async {
    if (!AppEnvironment.firebaseEnabled) {
      return DemoStore.activeMatch;
    }

    final partnerId = recommendation.profile.user.id;
    final pairKey = _pairKey(userId, partnerId);
    await _trustedAccessRepository.createCuratedIntroduction(
      payload: {
        'candidateUid': partnerId,
        'compatibilityScore': recommendation.compatibilityScore,
        'compatibilityReasons': recommendation.insights
            .map((reason) => reason.toMap())
            .toList(),
        'categoryScores': recommendation.categoryScores,
        'categoryDataCompleteness': recommendation.categoryDataCompleteness,
        'dataCompleteness': recommendation.dataCompleteness,
        'compatibilityAlgorithmVersion': recommendation.algorithmVersion,
        'searchScope': recommendation.scope.name,
        'generatedForTier': generatedForTier,
      },
    );

    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.match(pairKey),
    );
    return MatchModel.fromMap(snapshot.id, snapshot.data()!);
  }

  Future<Map<String, dynamic>> generateWeeklyCuratedCandidates() {
    if (!AppEnvironment.firebaseEnabled) {
      return Future.value({
        'status': 'created',
        'generatedCount': 1,
        'matchIds': [DemoStore.activeMatch.id],
        'weekKey': DemoStore.activeMatch.weekKey,
      });
    }
    return _trustedAccessRepository.generateWeeklyCuratedCandidates();
  }

  Future<MatchModel> markInterested(String matchId) async {
    return (await markInterestedWithResult(matchId)).match;
  }

  Future<MatchResponseResult> markInterestedWithResult(String matchId) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw StateError('A signed-in user is required to respond.');
    }

    final result = await _trustedAccessRepository.respondToCuratedMatch(
      matchId: matchId,
      action: 'interested',
    );

    final updated = await _firestoreService.getDocument(
      FirestorePaths.match(matchId),
    );
    final match = MatchModel.fromMap(updated.id, updated.data()!);
    if (result.status == MatchStatus.mutual.name) {
      // The notification service is called by UI/service orchestration where it
      // has dependencies. The persisted transition is idempotent and canonical.
    }
    return MatchResponseResult(
      match: match,
      createdMutual: result.status == MatchStatus.mutual.name,
    );
  }

  Future<MatchModel> passMatch(String matchId) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw StateError('A signed-in user is required to respond.');
    }

    await _trustedAccessRepository.respondToCuratedMatch(
      matchId: matchId,
      action: 'pass',
    );

    final updated = await _firestoreService.getDocument(
      FirestorePaths.match(matchId),
    );
    return MatchModel.fromMap(updated.id, updated.data()!);
  }

  Future<MatchModel> expireMatchIfNeeded(String matchId) async {
    if (!AppEnvironment.firebaseEnabled) {
      return DemoStore.activeMatch;
    }

    final result = await _trustedAccessRepository.expireCuratedMatch(
      matchId: matchId,
    );
    if (result.status == MatchStatus.expired.name) {
      await const AnalyticsEventService().track('curated_match_expired');
    }

    final updated = await _firestoreService.getDocument(
      FirestorePaths.match(matchId),
    );
    return MatchModel.fromMap(updated.id, updated.data()!);
  }

  Future<MatchModel> unmatch(String matchId) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw StateError('A signed-in user is required to unmatch.');
    }

    await _trustedAccessRepository.unmatchPair(matchId: matchId);

    await const AnalyticsEventService().track('match_unmatched');
    final updated = await _firestoreService.getDocument(
      FirestorePaths.match(matchId),
    );
    return MatchModel.fromMap(updated.id, updated.data()!);
  }

  Future<List<CompatibilityMatchResult>> fetchTopCompatibleUsers({
    int limit = 10,
    bool priorityMatching = false,
    Set<String> excludedPairKeys = const {},
  }) async {
    if (!AppEnvironment.firebaseEnabled) {
      if (DemoStore.blockedUserIds.contains(
        DemoStore.weeklyMatch.profile.user.id,
      )) {
        return const [];
      }
      return [DemoStore.weeklyMatch];
    }

    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) {
      return const [];
    }

    final currentUserProfile = await _buildCompatibilityProfile(currentUserId);
    if (currentUserProfile == null) {
      return const [];
    }
    if (!currentUserProfile.user.canReceiveNewIntroductions) {
      return const [];
    }
    final blockedUserIds = await _readBlockedUserIds(currentUserId);
    final activePartnerIds = await _readActivePartnerIds(currentUserId);

    final usersSnapshot = await _firestoreService
        .collection(FirestorePaths.users)
        .get();

    final candidates = <CompatibilityProfile>[];
    for (final doc in usersSnapshot.docs) {
      final candidate = await _buildCompatibilityProfile(
        doc.id,
        fallback: doc.data(),
      );
      if (candidate == null) {
        continue;
      }

      final blockedByCandidate = await _hasBlockedUser(
        ownerUserId: candidate.user.id,
        blockedUserId: currentUserId,
      );
      final eligibility = _eligibilityService.evaluate(
        currentUser: currentUserProfile,
        candidate: candidate,
        context: MatchEligibilityContext(
          blockedUserIds: blockedUserIds,
          blockedByUserIds: blockedByCandidate ? {candidate.user.id} : const {},
          activePartnerIds: activePartnerIds,
          historicalPairKeys: excludedPairKeys,
          candidateAccountData: doc.data(),
        ),
      );
      if (eligibility.eligible) {
        candidates.add(candidate);
      }
    }

    final baseRanked = _compatibilityEngine.rankCandidates(
      currentUser: currentUserProfile,
      candidates: candidates,
      limit: candidates.length,
      priorityMatching: priorityMatching,
    );
    return _applyPersonalizedRanking(
      currentUserId: currentUserId,
      ranked: baseRanked,
      limit: limit,
    );
  }

  Future<CompatibilityMatchResult?> fetchBestCompatibleUser() async {
    final ranked = await fetchTopCompatibleUsers(limit: 1);
    if (ranked.isEmpty) {
      return null;
    }
    return ranked.first;
  }

  Future<List<CuratedMatchSuggestion>> fetchCuratedSuggestions() async {
    if (!AppEnvironment.firebaseEnabled) {
      return [
        CuratedMatchSuggestion(
          match: DemoStore.activeMatch,
          partner: DemoStore.weeklyMatch.profile.user,
        ),
      ];
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return const [];
    }

    final snapshot = await _firestoreService
        .collection(FirestorePaths.matches)
        .where('participantIds', arrayContains: userId)
        .get();

    final suggestions = <CuratedMatchSuggestion>[];
    for (final doc in snapshot.docs) {
      var match = MatchModel.fromMap(doc.id, doc.data());
      if (match.status == MatchStatus.suggested ||
          match.status == MatchStatus.interested) {
        match = await expireMatchIfNeeded(match.id);
      }
      if (!match.suggestedForUserIds.contains(userId) &&
          match.status != MatchStatus.mutual) {
        continue;
      }
      if (match.status == MatchStatus.passed ||
          match.status == MatchStatus.expired ||
          match.status == MatchStatus.unmatched ||
          match.status == MatchStatus.blocked ||
          match.status == MatchStatus.archived) {
        continue;
      }
      final profile = await _fetchAuthorizedPartnerProfile(
        match.partnerIdFor(userId),
      );
      if (profile == null) {
        continue;
      }
      final partner = profile.user;
      final interests = profile.interests;
      final relationshipGoals = profile.relationshipGoals;
      final hasProfileUnlock = await _hasProfileUnlock(
        userId: userId,
        pairKey: match.pairKey ?? match.id,
      );
      suggestions.add(
        CuratedMatchSuggestion(
          match: match,
          partner: partner,
          publicInterests: const DatingProfileService().publicInterestPreview(
            interests,
            limit: 50,
          ),
          relationshipIntention: const DatingProfileService()
              .relationshipIntentionLabel(relationshipGoals),
          hasProfileUnlock: hasProfileUnlock,
        ),
      );
    }

    suggestions.sort((a, b) {
      final statusCompare = a.match.status.index.compareTo(
        b.match.status.index,
      );
      if (statusCompare != 0) {
        return statusCompare;
      }
      return b.match.compatibilityScore.compareTo(a.match.compatibilityScore);
    });
    return suggestions;
  }

  /// Another user's `users` doc and questionnaires are owner-only in
  /// firestore.rules, so the partner comes from getAuthorizedFullProfile:
  /// the full profile when this user may see it, teaser fields otherwise.
  Future<
    ({
      AppUser user,
      List<String> interests,
      Map<String, String> relationshipGoals,
    })?
  >
  _fetchAuthorizedPartnerProfile(String partnerId) async {
    final Map<String, dynamic> data;
    try {
      data = await _trustedAccessRepository.fetchAuthorizedFullProfile(
        candidateUid: partnerId,
      );
    } catch (error) {
      debugPrint('getAuthorizedFullProfile($partnerId) failed: $error');
      return null;
    }
    final relationshipGoals = <String, String>{
      for (final entry
          in Map<String, dynamic>.from(
            data['relationshipGoals'] as Map? ?? const {},
          ).entries)
        if (entry.value is String) entry.key: entry.value as String,
    };
    final interests = (data['interests'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    final profileFields = Map<String, dynamic>.from(data)
      ..remove('interests')
      ..remove('relationshipGoals');
    return (
      user: AppUser.fromMap(partnerId, profileFields),
      interests: interests,
      relationshipGoals: relationshipGoals,
    );
  }

  Future<bool> _hasProfileUnlock({
    required String userId,
    required String pairKey,
  }) async {
    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.userProfileUnlock(userId, pairKey),
    );
    return snapshot.exists;
  }

  Future<CompatibilityProfile?> _buildCompatibilityProfile(
    String userId, {
    Map<String, dynamic>? fallback,
  }) async {
    final userData =
        fallback ??
        (await _firestoreService.getDocument(
          FirestorePaths.user(userId),
        )).data();
    if (userData == null) {
      return null;
    }

    final user = AppUser.fromMap(userId, userData);
    final interests = await _readInterestSelections(userId);
    final lifestyle = await _readStringAnswers(
      userId,
      QuestionnaireIds.lifestyle,
      keys: const [
        'smoking',
        'drinking',
        'religionImportance',
        'exerciseFrequency',
        'dietPreference',
        'sleepingSchedule',
        'socialLifestyle',
      ],
    );
    final relationshipGoals = await _readStringAnswers(
      userId,
      QuestionnaireIds.relationshipGoals,
      keys: const [
        'marriage',
        'longTermRelationship',
        'casualDating',
        'children',
        'familyImportance',
        'careerPriority',
        'livingTogether',
      ],
    );
    final personality = await _readStringAnswers(
      userId,
      QuestionnaireIds.personality,
      keys: const [
        'introvertExtrovert',
        'planningVsSpontaneous',
        'riskTaking',
        'communicationStyle',
        'communicationFrequency',
        'conflictResolution',
        'humorStyle',
      ],
    );
    final preferences = await _readDynamicAnswers(
      userId,
      QuestionnaireIds.preferences,
      keys: const [
        'ageRange',
        'distancePreference',
        'dealBreakers',
        'relationshipExpectations',
      ],
    );
    final optional = await _readDynamicAnswers(
      userId,
      QuestionnaireIds.optionalCompatibility,
      keys: const [
        'affectionStyles',
        'financialAttitude',
        'pets',
        'relocationOpenness',
        'culturalBackgroundImportance',
        'politicalViewsImportance',
      ],
    );

    return CompatibilityProfile(
      user: user,
      interests: interests,
      lifestyleAnswers: lifestyle,
      relationshipGoalAnswers: relationshipGoals,
      personalityAnswers: personality,
      preferenceAnswers: preferences,
      optionalAnswers: optional,
    );
  }

  Future<List<String>> _readInterestSelections(String userId) async {
    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.userQuestionnaire(userId, QuestionnaireIds.interests),
    );
    final data = snapshot.data();
    if (data == null) {
      return const [];
    }

    final answers = Map<String, dynamic>.from(
      data['answers'] as Map<String, dynamic>? ?? const {},
    );

    return (answers['selectedInterests'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
  }

  Future<Map<String, String>> _readStringAnswers(
    String userId,
    String questionnaireId, {
    required List<String> keys,
  }) async {
    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.userQuestionnaire(userId, questionnaireId),
    );
    final data = snapshot.data();
    if (data == null) {
      return const {};
    }

    final answers = Map<String, dynamic>.from(
      data['answers'] as Map<String, dynamic>? ?? const {},
    );

    final result = <String, String>{};
    for (final key in keys) {
      final value = answers[key];
      if (value is String && value.isNotEmpty) {
        result[key] = value;
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> _readDynamicAnswers(
    String userId,
    String questionnaireId, {
    required List<String> keys,
  }) async {
    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.userQuestionnaire(userId, questionnaireId),
    );
    final data = snapshot.data();
    if (data == null) {
      return const {};
    }

    final answers = Map<String, dynamic>.from(
      data['answers'] as Map<String, dynamic>? ?? const {},
    );

    final result = <String, dynamic>{};
    for (final key in keys) {
      if (answers.containsKey(key)) {
        result[key] = answers[key];
      }
    }
    return result;
  }

  Future<Set<String>> _readBlockedUserIds(String userId) async {
    final snapshot = await _firestoreService.getCollection(
      FirestorePaths.userBlocks(userId),
    );
    return snapshot.docs.map((doc) => doc.id).toSet();
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

  Future<bool> _hasBlockedUser({
    required String ownerUserId,
    required String blockedUserId,
  }) async {
    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.userBlock(ownerUserId, blockedUserId),
    );
    return snapshot.exists;
  }

  Future<Set<String>> _readActivePartnerIds(String userId) async {
    final snapshot = await _firestoreService
        .collection(FirestorePaths.matches)
        .get();

    return snapshot.docs
        .map((doc) => MatchModel.fromMap(doc.id, doc.data()))
        .where(
          (match) =>
              (match.isLegacyActiveMatch &&
                  match.userId == userId &&
                  match.status == MatchStatus.active) ||
              (match.participantIds.contains(userId) &&
                  match.isConversationEligible),
        )
        .map((match) => match.partnerIdFor(userId))
        .where((partnerId) => partnerId.isNotEmpty && partnerId != userId)
        .toSet();
  }

  String _pairKey(String first, String second) {
    final sorted = [first, second]..sort();
    return '${sorted.first}_${sorted.last}';
  }

  Future<List<CompatibilityMatchResult>> _applyPersonalizedRanking({
    required String currentUserId,
    required List<CompatibilityMatchResult> ranked,
    required int limit,
  }) async {
    if (ranked.isEmpty) {
      return ranked;
    }

    final currentProfile = await _readPersonalizedProfile(currentUserId);
    final adjusted = <CompatibilityMatchResult>[];
    for (final result in ranked) {
      final candidateProfile = await _readPersonalizedProfile(
        result.profile.user.id,
      );
      final personalizedScore = _personalizedMatchingService
          .balancedPairRankingScore(
            result: result,
            currentUserProfile: currentProfile,
            candidateProfile: candidateProfile,
          );
      adjusted.add(
        result.copyWith(personalizedRankingScore: personalizedScore),
      );
    }

    adjusted.sort((a, b) {
      final rankingCompare =
          (b.personalizedRankingScore ?? b.compatibilityScore.toDouble())
              .compareTo(
                a.personalizedRankingScore ?? a.compatibilityScore.toDouble(),
              );
      if (rankingCompare != 0) {
        return rankingCompare;
      }

      final confidenceCompare = b.dataCompleteness.compareTo(
        a.dataCompleteness,
      );
      if (confidenceCompare != 0) {
        return confidenceCompare;
      }

      final baseCompare = b.compatibilityScore.compareTo(a.compatibilityScore);
      if (baseCompare != 0) {
        return baseCompare;
      }

      return a.scope.index.compareTo(b.scope.index);
    });

    return adjusted.take(limit).toList();
  }

  Future<PersonalizedMatchingProfile> _readPersonalizedProfile(
    String userId,
  ) async {
    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.userSetting(userId, 'personalized_matching_profile'),
    );
    return PersonalizedMatchingProfile.fromMap(userId, snapshot.data());
  }
}
