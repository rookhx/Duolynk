import 'package:flutter_test/flutter_test.dart';

import 'package:duolynk/models/app_user.dart';
import 'package:duolynk/models/match_model.dart';
import 'package:duolynk/models/subscription_model.dart';
import 'package:duolynk/models/user_report.dart';
import 'package:duolynk/services/chat/conversation_access_service.dart';
import 'package:duolynk/services/matching/match_repeat_policy_service.dart';
import 'package:duolynk/services/safety/age_policy_service.dart';

void main() {
  const agePolicy = AgePolicyService();

  test('exact birthday age calculation handles boundaries', () {
    final dob = DateTime.utc(2008, 9, 22);

    expect(agePolicy.ageOnDate(dob, DateTime.utc(2026, 9, 21)), 17);
    expect(agePolicy.ageOnDate(dob, DateTime.utc(2026, 9, 22)), 18);
    expect(agePolicy.ageOnDate(dob, DateTime.utc(2026, 9, 23)), 18);
  });

  test('DOB drives display age and adult eligibility', () {
    final underage = _user(
      dateOfBirth: DateTime.utc(2008, 9, 22),
      now: DateTime.utc(2026, 9, 21),
    );
    final adult = _user(
      dateOfBirth: DateTime.utc(2008, 9, 21),
      now: DateTime.utc(2026, 9, 21),
    );

    expect(underage.displayAge(now: DateTime.utc(2026, 9, 21)), 17);
    expect(adult.displayAge(now: DateTime.utc(2026, 9, 21)), 18);
  });

  test('DOB is not exposed in public profile serialization', () {
    final user = _user(dateOfBirth: DateTime.utc(1997, 4, 3));
    final public = user.toPublicProfileMap(now: DateTime.utc(2026, 9, 21));

    expect(public['age'], 29);
    expect(public.containsKey('dateOfBirth'), isFalse);
    expect(public.containsKey('dob'), isFalse);
  });

  test('legacy age-only user deserializes without fake DOB', () {
    final user = AppUser.fromMap('legacy', {
      'email': 'legacy@example.com',
      'displayName': 'Legacy',
      'age': 31,
      'gender': 'Woman',
      'interestedIn': ['Men'],
      'isProfileComplete': true,
    });

    expect(user.dateOfBirth, isNull);
    expect(user.displayAge(), 31);
    expect(user.canReceiveNewIntroductions, isTrue);
  });

  test('under-18 user cannot receive curated introduction', () {
    final user = _user(
      dateOfBirth: DateTime.utc(2010, 1, 1),
      isProfileComplete: true,
    );

    expect(user.canReceiveNewIntroductions, isFalse);
  });

  test('Premium cannot bypass age requirement or quotas', () {
    final premium = _subscription(SubscriptionTier.premium);
    final underage = _user(dateOfBirth: DateTime.utc(2010, 1, 1));

    expect(premium.weeklyMatchQuota, 3);
    expect(underage.canUseDatingFeatures, isFalse);
  });

  test('paused adult remains paused', () {
    final user = _user(datingStatus: DatingStatus.paused);

    expect(user.isAdult, isTrue);
    expect(user.canReceiveNewIntroductions, isFalse);
  });

  test('moderation states restrict matching and messaging', () {
    const access = ConversationAccessService();
    for (final status in [
      ModerationStatus.underReview,
      ModerationStatus.suspended,
      ModerationStatus.banned,
    ]) {
      final user = _user(moderationStatus: status);

      expect(user.canReceiveNewIntroductions, isFalse);
      expect(
        access.canSendMessageForAccount(hasPremium: true, user: user),
        isFalse,
      );
    }
  });

  test('report category serializes and details are limited', () {
    final report = UserReport(
      id: 'report',
      reporterUserId: 'a',
      targetUserId: 'b',
      category: ReportCategory.underageConcern,
      details: List.filled(600, 'x').join(),
      createdAt: DateTime.utc(2026, 9, 21),
      source: 'test',
      matchId: 'a_b',
      pairKey: 'a_b',
    );
    final map = report.toMap();

    expect(map['category'], ReportCategory.underageConcern.name);
    expect(map['priority'], 'high');
    expect((map['details'] as String).length, UserReport.detailsCharacterLimit);
  });

  test('report is private model data, not shared match data', () {
    final report = UserReport(
      id: 'report',
      reporterUserId: 'a',
      targetUserId: 'b',
      category: ReportCategory.scam,
      createdAt: DateTime.utc(2026, 9, 21),
      source: 'chat',
      pairKey: 'a_b',
    );
    final match = MatchModel(
      id: 'a_b',
      userId: 'a',
      partnerId: 'b',
      compatibilityScore: 90,
      status: MatchStatus.active,
      compatibilityReasons: const [],
      createdAt: DateTime.utc(2026, 9, 1),
      expiresAt: DateTime.utc(2026, 9, 8),
      pairKey: 'a_b',
    );

    expect(report.toMap().containsKey('reporterUserId'), isTrue);
    expect(match.toMap().containsKey('reporterUserId'), isFalse);
    expect(match.toMap().containsKey('details'), isFalse);
  });

  test(
    'report plus block preserves report while excluding future recommendation',
    () {
      final report = UserReport(
        id: 'report',
        reporterUserId: 'a',
        targetUserId: 'b',
        category: ReportCategory.harassment,
        createdAt: DateTime.utc(2026, 9, 21),
        source: 'match',
      );
      final blocked = MatchModel(
        id: 'a_b',
        userId: 'a',
        partnerId: 'b',
        compatibilityScore: 90,
        status: MatchStatus.blocked,
        compatibilityReasons: const [],
        createdAt: DateTime.utc(2026, 9, 1),
        expiresAt: DateTime.utc(2026, 9, 8),
        pairKey: 'a_b',
      );

      expect(report.category, ReportCategory.harassment);
      expect(
        const MatchRepeatPolicyService().excludesFromRecommendations(
          blocked,
          DateTime.utc(2027, 1, 1),
        ),
        isTrue,
      );
    },
  );

  test('verification and photo moderation defaults are conservative', () {
    final user = _user();

    expect(user.verificationStatus, VerificationStatus.unverified);
    expect(_subscription(SubscriptionTier.premium).hasPremiumAccess, isTrue);
    expect(
      user
          .copyWith(verificationStatus: VerificationStatus.verified)
          .verificationStatus,
      VerificationStatus.verified,
    );
  });

  test('editable profile map cannot mark trusted safety fields', () {
    final user = _user(
      moderationStatus: ModerationStatus.banned,
      verificationStatus: VerificationStatus.verified,
    );
    final editable = user.toEditableMap();

    expect(editable.containsKey('moderationStatus'), isFalse);
    expect(editable.containsKey('verificationStatus'), isFalse);
  });

  test('photo moderation metadata supports pending approved rejected', () {
    final user = _user(
      photoModerationStatuses: const {
        'one': PhotoModerationStatus.pending,
        'two': PhotoModerationStatus.approved,
        'three': PhotoModerationStatus.rejected,
      },
    );

    expect(user.photoModerationStatuses['one'], PhotoModerationStatus.pending);
    expect(user.photoModerationStatuses['two'], PhotoModerationStatus.approved);
    expect(
      user.photoModerationStatuses['three'],
      PhotoModerationStatus.rejected,
    );
  });

  test('bio and prompts remain plain stored text', () {
    final user = _user(bio: '<b>Hello</b>');

    expect(user.bio, '<b>Hello</b>');
    expect(user.toPublicProfileMap()['bio'], '<b>Hello</b>');
  });

  test('basic and premium quotas remain unchanged', () {
    expect(_subscription(SubscriptionTier.free).weeklyMatchQuota, 1);
    expect(_subscription(SubscriptionTier.premium).weeklyMatchQuota, 3);
  });
}

AppUser _user({
  DateTime? dateOfBirth,
  DateTime? now,
  DatingStatus datingStatus = DatingStatus.active,
  ModerationStatus moderationStatus = ModerationStatus.active,
  VerificationStatus verificationStatus = VerificationStatus.unverified,
  Map<String, PhotoModerationStatus> photoModerationStatuses = const {},
  bool isProfileComplete = true,
  String? bio,
}) {
  final fallbackAge = dateOfBirth == null
      ? 29
      : const AgePolicyService().ageOnDate(
          dateOfBirth,
          now ?? DateTime.utc(2026, 9, 21),
        );
  return AppUser(
    id: 'a',
    email: 'a@example.com',
    displayName: 'Avery',
    age: fallbackAge,
    dateOfBirth: dateOfBirth,
    gender: 'Woman',
    interestedIn: const ['Men'],
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    country: 'United States',
    city: 'Chicago',
    datingStatus: datingStatus,
    moderationStatus: moderationStatus,
    verificationStatus: verificationStatus,
    photoModerationStatuses: photoModerationStatuses,
    isProfileComplete: isProfileComplete,
    bio: bio,
  );
}

SubscriptionModel _subscription(SubscriptionTier tier) {
  return SubscriptionModel(
    id: tier.name,
    userId: 'a',
    tier: tier,
    platform: SubscriptionPlatform.revenueCat,
    isActive: tier == SubscriptionTier.premium,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}
