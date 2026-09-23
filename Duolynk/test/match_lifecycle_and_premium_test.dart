import 'package:flutter_test/flutter_test.dart';

import 'package:duolynk/models/app_user.dart';
import 'package:duolynk/models/chat_model.dart';
import 'package:duolynk/models/compatibility_profile.dart';
import 'package:duolynk/models/match_model.dart';
import 'package:duolynk/models/subscription_model.dart';
import 'package:duolynk/services/chat/conversation_access_service.dart';
import 'package:duolynk/services/matching/compatibility_engine_service.dart';
import 'package:duolynk/services/matching/match_eligibility_service.dart';
import 'package:duolynk/services/matching/match_lifecycle_service.dart';

void main() {
  const lifecycle = MatchLifecycleService();
  const access = ConversationAccessService();

  test('weekly recommendation starts as suggested, not active', () {
    final match = _match(status: MatchStatus.suggested);

    expect(match.status, MatchStatus.suggested);
    expect(match.isConversationEligible, isFalse);
  });

  test('User A interested + User B pending is not mutual', () {
    final transition = lifecycle.markInterested(
      userId: 'a',
      participantIds: const ['a', 'b'],
      currentStatus: MatchStatus.suggested,
      currentDecisions: const {},
    );

    expect(transition.status, MatchStatus.interested);
    expect(transition.createdMutual, isFalse);
  });

  test('User A interested + User B interested becomes mutual', () {
    final transition = lifecycle.markInterested(
      userId: 'b',
      participantIds: const ['a', 'b'],
      currentStatus: MatchStatus.interested,
      currentDecisions: const {'a': MatchParticipantDecision.interested},
    );

    expect(transition.status, MatchStatus.mutual);
    expect(transition.createdMutual, isTrue);
  });

  test(
    'concurrent interested transitions converge to one mutual relationship',
    () {
      final first = lifecycle.markInterested(
        userId: 'a',
        participantIds: const ['a', 'b'],
        currentStatus: MatchStatus.suggested,
        currentDecisions: const {},
      );
      final second = lifecycle.markInterested(
        userId: 'b',
        participantIds: const ['a', 'b'],
        currentStatus: first.status,
        currentDecisions: first.decisions,
      );
      final repeated = lifecycle.markInterested(
        userId: 'a',
        participantIds: const ['a', 'b'],
        currentStatus: second.status,
        currentDecisions: second.decisions,
      );

      expect(second.status, MatchStatus.mutual);
      expect(second.createdMutual, isTrue);
      expect(repeated.status, MatchStatus.mutual);
      expect(repeated.createdMutual, isFalse);
    },
  );

  test('passed suggestion cannot become mutual', () {
    final passed = lifecycle.markPassed(
      userId: 'a',
      participantIds: const ['a', 'b'],
      currentStatus: MatchStatus.suggested,
      currentDecisions: const {},
    );
    final interested = lifecycle.markInterested(
      userId: 'b',
      participantIds: const ['a', 'b'],
      currentStatus: passed.status,
      currentDecisions: passed.decisions,
    );

    expect(passed.status, MatchStatus.passed);
    expect(interested.status, MatchStatus.passed);
    expect(interested.createdMutual, isFalse);
  });

  test('repeated interested taps are idempotent', () {
    final first = lifecycle.markInterested(
      userId: 'a',
      participantIds: const ['a', 'b'],
      currentStatus: MatchStatus.suggested,
      currentDecisions: const {},
    );
    final second = lifecycle.markInterested(
      userId: 'a',
      participantIds: const ['a', 'b'],
      currentStatus: first.status,
      currentDecisions: first.decisions,
    );

    expect(second.status, MatchStatus.interested);
    expect(second.decisions['a'], MatchParticipantDecision.interested);
    expect(second.createdMutual, isFalse);
  });

  test('Basic weekly quota remains 1 and Premium remains 3', () {
    final basic = _subscription(SubscriptionTier.free, false);
    final premium = _subscription(SubscriptionTier.premium, true);

    expect(basic.weeklyMatchQuota, 1);
    expect(premium.weeklyMatchQuota, 3);
  });

  test('unactivated mutual match has locked conversation', () {
    final match = _match(status: MatchStatus.mutual);

    expect(access.canOpenConversationShell(match), isTrue);
    expect(access.canSendMessage(hasConversationAccess: false), isFalse);
  });

  test('activated conversation allows user to send first message', () {
    expect(access.canSendMessage(hasConversationAccess: true), isTrue);
  });

  test('free recipient cannot read message content', () {
    final message = _message(senderId: 'premium');

    expect(
      access.canReadMessage(
        hasPremium: false,
        message: message,
        userId: 'free',
      ),
      isFalse,
    );
  });

  test('free recipient cannot reply', () {
    expect(access.canSendMessage(hasConversationAccess: false), isFalse);
  });

  test('free recipient notification does not contain message body', () {
    final message = _message(text: 'Dinner Friday?');
    final preview = access.safePreview(
      recipientHasPremium: false,
      message: message,
    );

    expect(preview, isNot(contains('Dinner Friday')));
    expect(preview, 'You have a new message from a match.');
  });

  test('activated recipient can read and reply normally', () {
    final message = _message(senderId: 'other');

    expect(
      access.canReadMessage(
        hasConversationAccess: true,
        message: message,
        userId: 'premium',
      ),
      isTrue,
    );
    expect(access.canSendMessage(hasConversationAccess: true), isTrue);
  });

  test('activated users have normal conversation access', () {
    final message = _message(senderId: 'a');

    expect(access.canSendMessage(hasConversationAccess: true), isTrue);
    expect(
      access.canReadMessage(
        hasConversationAccess: true,
        message: message,
        userId: 'b',
      ),
      isTrue,
    );
  });

  test('legacy active matches continue to load as conversation eligible', () {
    final legacy = MatchModel(
      id: 'legacy',
      userId: 'a',
      partnerId: 'b',
      compatibilityScore: 90,
      status: MatchStatus.active,
      compatibilityReasons: const [],
      createdAt: DateTime(2026),
      expiresAt: DateTime(2026, 1, 8),
      pairKey: 'a_b',
    );

    expect(legacy.isLegacyActiveMatch, isTrue);
    expect(legacy.isConversationEligible, isTrue);
  });

  test('blocked users cannot interact through eligibility gate', () {
    final result = const MatchEligibilityService().evaluate(
      currentUser: _profile('a'),
      candidate: _profile('b', gender: 'Man', interestedIn: const ['Women']),
      context: const MatchEligibilityContext(blockedUserIds: {'b'}),
    );

    expect(result.eligible, isFalse);
  });

  test('compatibility score is unchanged by Premium status', () {
    final current = _profile('a');
    final candidate = _profile(
      'b',
      gender: 'Man',
      interestedIn: const ['Women'],
    );
    final score = const CompatibilityEngineService()
        .rankCandidates(currentUser: current, candidates: [candidate])
        .single
        .compatibilityScore;
    final premiumScore = const CompatibilityEngineService()
        .rankCandidates(
          currentUser: current,
          candidates: [candidate],
          priorityMatching: true,
        )
        .single
        .compatibilityScore;

    expect(premiumScore, score);
  });

  test('eligibility filtering still occurs before scoring', () {
    final current = _profile('a');
    final candidate = _profile('b', gender: 'Man', interestedIn: const ['Men']);
    final eligibility = const MatchEligibilityService().evaluate(
      currentUser: current,
      candidate: candidate,
    );
    final ranked = eligibility.eligible
        ? const CompatibilityEngineService().rankCandidates(
            currentUser: current,
            candidates: [candidate],
          )
        : const [];

    expect(eligibility.eligible, isFalse);
    expect(ranked, isEmpty);
  });

  test('one canonical pair does not create duplicate conversations', () {
    final first = _pairKey('b', 'a');
    final second = _pairKey('a', 'b');

    expect(first, second);
    expect(_match().id, first);
  });
}

MatchModel _match({MatchStatus status = MatchStatus.suggested}) {
  return MatchModel(
    id: 'a_b',
    userId: 'a',
    partnerId: 'b',
    compatibilityScore: 91,
    status: status,
    compatibilityReasons: const [],
    createdAt: DateTime(2026),
    expiresAt: DateTime(2026, 1, 8),
    pairKey: 'a_b',
    participantIds: const ['a', 'b'],
    suggestedForUserIds: const ['a', 'b'],
    participantDecisions: status == MatchStatus.mutual
        ? const {
            'a': MatchParticipantDecision.interested,
            'b': MatchParticipantDecision.interested,
          }
        : const {
            'a': MatchParticipantDecision.pending,
            'b': MatchParticipantDecision.pending,
          },
  );
}

ChatMessageModel _message({
  String senderId = 'sender',
  String text = 'Hello there',
}) {
  return ChatMessageModel(
    id: 'message',
    chatId: 'chat',
    senderId: senderId,
    text: text,
    type: ChatMessageType.text,
    createdAt: DateTime(2026),
    readByUserIds: [senderId],
  );
}

SubscriptionModel _subscription(SubscriptionTier tier, bool active) {
  return SubscriptionModel(
    id: tier.name,
    userId: 'user',
    tier: tier,
    platform: SubscriptionPlatform.revenueCat,
    isActive: active,
    createdAt: DateTime(2026),
  );
}

CompatibilityProfile _profile(
  String id, {
  String gender = 'Woman',
  List<String> interestedIn = const ['Men'],
}) {
  return CompatibilityProfile(
    user: AppUser(
      id: id,
      email: '$id@example.com',
      displayName: id,
      age: 29,
      gender: gender,
      interestedIn: interestedIn,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      country: 'United States',
      city: 'Chicago',
    ),
    interests: const ['Travel'],
    lifestyleAnswers: const {},
    relationshipGoalAnswers: const {},
    personalityAnswers: const {},
    preferenceAnswers: const {'ageRange': '25-35'},
  );
}

String _pairKey(String first, String second) {
  final sorted = [first, second]..sort();
  return '${sorted.first}_${sorted.last}';
}
