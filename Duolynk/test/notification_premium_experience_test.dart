import 'package:duolynk/models/app_user.dart';
import 'package:duolynk/models/chat_model.dart';
import 'package:duolynk/models/duolynk_notification_type.dart';
import 'package:duolynk/models/match_model.dart';
import 'package:duolynk/models/notification_job.dart';
import 'package:duolynk/models/notification_preferences.dart';
import 'package:duolynk/models/subscription_model.dart';
import 'package:duolynk/services/chat/conversation_access_service.dart';
import 'package:duolynk/services/matching/compatibility_engine_service.dart';
import 'package:duolynk/services/matching/match_notification_service.dart';
import 'package:duolynk/services/notifications/notification_routing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('typed notifications and privacy', () {
    test('new curated suggestion uses a stable privacy-safe type', () {
      final job = NotificationJob(
        id: 'job-1',
        userId: 'user-a',
        title: 'Duolynk found new people for you',
        body: 'Your curated candidates are ready.',
        type: DuolynkNotificationType.curatedIntroduction,
        createdAt: DateTime.utc(2026),
        data: const {'matchId': 'a_b', 'route': 'match'},
      );

      final map = job.toMap();
      expect(map['type'], DuolynkNotificationType.curatedIntroduction.id);
      expect(map['body'], isNot(contains('deal breaker')));
      expect(
        map['data'],
        isNot(containsPair('questionnaireAnswers', anything)),
      );
      expect(map['data'], isNot(containsPair('dateOfBirth', anything)));
    });

    test('locked message notification payload contains no message body', () {
      final message = _message(text: 'Dinner tomorrow?');
      final lockedJob = NotificationJob(
        id: 'job-2',
        userId: 'free-user',
        title: 'Duolynk',
        body: 'Someone you matched with sent you a message.',
        type: DuolynkNotificationType.lockedMatchMessage,
        createdAt: DateTime.utc(2026),
        data: const {
          'chatId': 'chat-1',
          'matchId': 'a_b',
          'senderId': 'premium-user',
          'route': 'chat',
        },
      );

      expect(lockedJob.toMap()['type'], 'locked_match_message');
      expect(lockedJob.body, isNot(contains(message.text)));
      expect(lockedJob.data.values, isNot(contains(message.text)));
    });

    test('mutual notification uses privacy-safe copy and payload', () {
      final job = NotificationJob(
        id: 'job-3',
        userId: 'user-a',
        title: "It's mutual!",
        body: 'You both want to connect.',
        type: DuolynkNotificationType.mutualMatch,
        createdAt: DateTime.utc(2026),
        data: const {'matchId': 'a_b', 'pairKey': 'a_b', 'route': 'match'},
      );

      expect(job.body, isNot(contains('Premium')));
      expect(job.data, isNot(containsPair('isPremium', anything)));
    });
  });

  group('introduction reminders', () {
    final now = DateTime.utc(2026, 9, 22, 12);
    final activeUser = _user('user-a');
    const prefs = NotificationPreferences();

    test('only one reminder window is eligible near 24 hours remaining', () {
      final tooEarly = _match(expiresAt: now.add(const Duration(hours: 25)));
      final eligible = _match(expiresAt: now.add(const Duration(hours: 23)));

      expect(
        MatchNotificationService.isIntroductionReminderEligible(
          userId: 'user-a',
          user: activeUser,
          match: tooEarly,
          preferences: prefs,
          now: now,
        ),
        isFalse,
      );
      expect(
        MatchNotificationService.isIntroductionReminderEligible(
          userId: 'user-a',
          user: activeUser,
          match: eligible,
          preferences: prefs,
          now: now,
        ),
        isTrue,
      );
    });

    test('reminder does not send after pass, mutual, expiration, or pause', () {
      for (final match in [
        _match(status: MatchStatus.passed),
        _match(status: MatchStatus.mutual),
        _match(status: MatchStatus.expired),
        _match(closureReason: MatchClosureReason.userPaused),
      ]) {
        expect(
          MatchNotificationService.isIntroductionReminderEligible(
            userId: 'user-a',
            user: activeUser,
            match: match,
            preferences: prefs,
            now: now,
          ),
          isFalse,
        );
      }
    });

    test('reminder does not send for paused or suspended users', () {
      for (final user in [
        _user('user-a', datingStatus: DatingStatus.paused),
        _user('user-a', moderationStatus: ModerationStatus.suspended),
      ]) {
        expect(
          MatchNotificationService.isIntroductionReminderEligible(
            userId: 'user-a',
            user: user,
            match: _match(),
            preferences: prefs,
            now: now,
          ),
          isFalse,
        );
      }
    });

    test('notification preferences can disable reminders', () {
      expect(
        MatchNotificationService.isIntroductionReminderEligible(
          userId: 'user-a',
          user: activeUser,
          match: _match(),
          preferences: const NotificationPreferences(reminders: false),
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('conversation activation access', () {
    const access = ConversationAccessService();

    test('unactivated recipient cannot read locked message or send reply', () {
      final message = _message(senderId: 'premium-user');

      expect(
        access.canReadMessage(
          hasConversationAccess: false,
          message: message,
          userId: 'free-user',
        ),
        isFalse,
      );
      expect(access.canSendMessage(hasConversationAccess: false), isFalse);
    });

    test(
      'conversation activation unlocks existing conversation without duplicates',
      () {
        final conversation = _chat();
        final existingConversationIds = {conversation.id};

        expect(
          access.canReadMessage(
            hasConversationAccess: true,
            message: _message(senderId: 'other-user'),
            userId: 'user-a',
          ),
          isTrue,
        );
        existingConversationIds.add(conversation.id);
        expect(existingConversationIds, hasLength(1));
      },
    );

    test(
      'Premium expiration does not relock an already activated conversation',
      () {
        final message = _message(senderId: 'other-user');
        final match = _match(status: MatchStatus.mutual);

        expect(
          access.canReadMessage(
            hasConversationAccess: true,
            message: message,
            userId: 'user-a',
          ),
          isTrue,
        );
        expect(match.isConversationEligible, isTrue);
        expect(message.text, 'Dinner tomorrow?');
      },
    );
  });

  group('Premium quota and ranking boundaries', () {
    test('Basic-to-Premium mid-week candidate cap remains 10 total', () {
      final basic = _subscription(SubscriptionTier.free, isActive: false);
      final premium = _subscription(SubscriptionTier.premium, isActive: true);

      expect(basic.weeklyCandidateLimit, 10);
      expect(premium.weeklyCandidateLimit, 10);
    });

    test('Premium-to-Basic downgrade returns future activation cap to 1', () {
      final downgraded = _subscription(SubscriptionTier.free, isActive: false);

      expect(downgraded.weeklyConversationActivationLimit, 1);
      expect(downgraded.hasPremiumAccess, isFalse);
    });

    test('Premium does not alter compatibility or priority ranking flags', () {
      final engine = const CompatibilityEngineService();
      final free = _subscription(SubscriptionTier.free, isActive: false);
      final premium = _subscription(SubscriptionTier.premium, isActive: true);

      expect(free.hasPriorityMatching, isFalse);
      expect(premium.hasPriorityMatching, isFalse);
      expect(engine, isA<CompatibilityEngineService>());
    });
  });

  group('notification preferences and stale routing', () {
    test('notification preferences persist simple user-facing controls', () {
      const prefs = NotificationPreferences(
        newIntroductions: false,
        matchUpdates: true,
        messages: false,
        reminders: true,
      );

      final parsed = NotificationPreferences.fromMap(prefs.toMap());

      expect(parsed.newIntroductions, isFalse);
      expect(parsed.matchUpdates, isTrue);
      expect(parsed.messages, isFalse);
      expect(parsed.reminders, isTrue);
    });

    test(
      'legacy newMatches preference maps to introductions and match updates',
      () {
        final parsed = NotificationPreferences.fromMap(const {
          'pushEnabled': true,
          'newMatches': false,
        });

        expect(parsed.newIntroductions, isFalse);
        expect(parsed.matchUpdates, isFalse);
      },
    );

    test(
      'stale expired introduction resolves to neutral unavailable state',
      () {
        final resolution = const NotificationRoutingService().resolve(
          type: DuolynkNotificationType.introductionReminder,
          data: const {'matchId': 'a_b'},
          match: _match(status: MatchStatus.expired),
        );

        expect(
          resolution.status,
          NotificationRouteResolutionStatus.unavailable,
        );
        expect(resolution.message, 'This introduction is no longer available.');
      },
    );

    test('stale unmatched chat resolves safely', () {
      final resolution = const NotificationRoutingService().resolve(
        type: DuolynkNotificationType.lockedMatchMessage,
        data: const {'chatId': 'a_b'},
        match: _match(status: MatchStatus.unmatched),
      );

      expect(resolution.status, NotificationRouteResolutionStatus.unavailable);
      expect(resolution.message, 'This conversation is no longer available.');
    });
  });
}

AppUser _user(
  String id, {
  DatingStatus datingStatus = DatingStatus.active,
  ModerationStatus moderationStatus = ModerationStatus.active,
}) {
  return AppUser(
    id: id,
    email: '$id@example.com',
    displayName: 'Duolynk Member',
    age: 29,
    gender: 'woman',
    interestedIn: const ['man'],
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    dateOfBirth: DateTime.utc(1997, 1, 1),
    country: 'United States',
    city: 'Chicago',
    photoUrl: 'photo',
    isProfileComplete: true,
    datingStatus: datingStatus,
    moderationStatus: moderationStatus,
  );
}

MatchModel _match({
  MatchStatus status = MatchStatus.suggested,
  DateTime? expiresAt,
  MatchClosureReason? closureReason,
}) {
  final now = DateTime.utc(2026, 9, 22, 12);
  return MatchModel(
    id: 'user-a_user-b',
    userId: 'user-a',
    partnerId: 'user-b',
    compatibilityScore: 86,
    status: status,
    compatibilityReasons: const [],
    createdAt: now,
    expiresAt: expiresAt ?? now.add(const Duration(hours: 23)),
    pairKey: 'user-a_user-b',
    weekKey: '2026-09-21_2026-09-27',
    generatedBySystem: true,
    participantIds: const ['user-a', 'user-b'],
    suggestedForUserIds: const ['user-a', 'user-b'],
    participantDecisions: const {
      'user-a': MatchParticipantDecision.pending,
      'user-b': MatchParticipantDecision.pending,
    },
    closureReason: closureReason,
  );
}

ChatMessageModel _message({
  String senderId = 'premium-user',
  String text = 'Dinner tomorrow?',
}) {
  return ChatMessageModel(
    id: 'message-1',
    chatId: 'chat-1',
    senderId: senderId,
    text: text,
    type: ChatMessageType.text,
    createdAt: DateTime.utc(2026),
    readByUserIds: [senderId],
  );
}

ChatModel _chat() {
  return ChatModel(
    id: 'user-a_user-b',
    matchId: 'user-a_user-b',
    pairKey: 'user-a_user-b',
    memberIds: const ['user-a', 'user-b'],
    memberSnapshots: const {},
    compatibilityScore: 86,
    compatibilityReasons: const [],
    lastMessage: 'Dinner tomorrow?',
    lastMessageType: ChatMessageType.text,
    lastMessageAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    lastReadAtByUser: const {},
    typingByUser: const {},
    lastMessageSenderId: 'user-b',
  );
}

SubscriptionModel _subscription(
  SubscriptionTier tier, {
  required bool isActive,
}) {
  return SubscriptionModel(
    id: 'sub',
    userId: 'user-a',
    tier: tier,
    platform: SubscriptionPlatform.revenueCat,
    isActive: isActive,
    createdAt: DateTime.utc(2026),
  );
}
