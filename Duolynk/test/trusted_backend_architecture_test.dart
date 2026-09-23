import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firebase Functions backend exposes trusted access operations', () {
    final index = File('functions/src/index.ts').readAsStringSync();
    final unlock = File(
      'functions/src/access/unlockCandidateProfile.ts',
    ).readAsStringSync();
    final activation = File(
      'functions/src/access/activateConversation.ts',
    ).readAsStringSync();

    expect(index, contains('unlockCandidateProfile'));
    expect(index, contains('activateConversation'));
    expect(index, contains('createCuratedIntroduction'));
    expect(index, contains('generateWeeklyCuratedCandidates'));
    expect(index, contains('respondToCuratedMatch'));
    expect(index, contains('ensureConversationForMatch'));
    expect(index, contains('revenueCatWebhook'));
    expect(index, contains('generateProfileTeaser'));
    expect(unlock, contains('PROFILE_UNLOCK_LIMIT_BASIC'));
    expect(unlock, contains('db.runTransaction'));
    expect(unlock, isNot(contains('isPremium')));
    expect(activation, contains('CONVERSATION_ACTIVATION_LIMIT_BASIC'));
    expect(activation, contains('CONVERSATION_ACTIVATION_LIMIT_PREMIUM'));
    expect(activation, contains('conversationActivationCount'));
  });

  test('trusted backend owns match creation and lifecycle writes', () {
    final creation = File(
      'functions/src/matching/createCuratedIntroduction.ts',
    ).readAsStringSync();
    final generation = File(
      'functions/src/matching/generateWeeklyCuratedCandidates.ts',
    ).readAsStringSync();
    final weeklyService = File(
      'lib/services/matching/weekly_match_service.dart',
    ).readAsStringSync();
    final lifecycle = File(
      'functions/src/matching/matchLifecycle.ts',
    ).readAsStringSync();
    final chat = File(
      'functions/src/chat/ensureConversationForMatch.ts',
    ).readAsStringSync();
    final rules = File('firestore.rules').readAsStringSync();

    expect(creation, contains('WEEKLY_CANDIDATE_LIMIT'));
    expect(creation, contains('request.auth.token.admin'));
    expect(creation, contains('server-authoritative'));
    expect(creation, contains('curatedCandidateCount'));
    expect(creation, contains('db.runTransaction'));
    expect(generation, contains('generateWeeklyCuratedCandidates'));
    expect(generation, contains('isEligiblePair'));
    expect(generation, contains('scoreCompatibility'));
    expect(generation, contains('balancedPairRankingScore'));
    expect(generation, isNot(contains('CompatibilityEngineService')));
    expect(weeklyService, contains('generateWeeklyCuratedCandidates'));
    expect(weeklyService, isNot(contains('fetchTopCompatibleUsers(')));
    expect(lifecycle, contains('respondToCuratedMatch'));
    expect(lifecycle, contains('participantDecisions'));
    expect(lifecycle, contains('unmatchPair'));
    expect(chat, contains('ensureConversationForMatch'));
    expect(chat, contains('MATCH_CONVERSATION_STATUSES'));
    expect(rules, contains('match /matches/{matchId}'));
    expect(rules, contains('allow create, update, delete: if isPrivileged();'));
    expect(rules, contains('allow create: if isPrivileged();'));
  });

  test('trusted entitlement mirror is server-owned', () {
    final webhook = File(
      'functions/src/subscriptions/revenueCatWebhook.ts',
    ).readAsStringSync();
    final rules = File('firestore.rules').readAsStringSync();

    expect(webhook, contains('REVENUECAT_WEBHOOK_SECRET'));
    expect(webhook, contains('entitlementPath(uid)'));
    expect(rules, contains('match /entitlements/{userId}'));
    expect(rules, contains('allow write: if isPrivileged();'));
  });

  test('storage rules separate protected originals from teaser images', () {
    final rules = File('storage.rules').readAsStringSync();
    final fullProfile = File(
      'functions/src/profile/getAuthorizedFullProfile.ts',
    ).readAsStringSync();
    final profileRepository = File(
      'lib/features/profile/data/profile_repository.dart',
    ).readAsStringSync();

    expect(rules, contains('match /users/{userId}/profile/{fileName}'));
    expect(rules, contains('canReadOriginalProfilePhoto(userId)'));
    expect(rules, contains('hasProfileUnlock(request.auth.uid, ownerId)'));
    expect(rules, contains('hasPremiumCandidateAccess'));
    expect(rules, contains('match /profileTeasers/{userId}/{fileName}'));
    expect(fullProfile, contains('getSignedUrl'));
    expect(fullProfile, contains('15 * 60 * 1000'));
    expect(profileRepository, contains('returnDownloadUrl: false'));
  });

  test(
    'legacy active conversation migration grants do not consume weekly quota',
    () {
      final migration = File(
        'functions/src/access/migrateLegacyActiveConversations.ts',
      ).readAsStringSync();

      expect(migration, contains('GRANT_TYPE_LEGACY_MIGRATION'));
      expect(migration, contains('conversationActivations'));
      expect(migration, isNot(contains('conversationActivationCount')));
    },
  );
}
