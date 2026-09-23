import '../../models/app_user.dart';
import '../../models/chat_model.dart';
import '../../models/compatibility_insight.dart';
import '../../models/compatibility_match_result.dart';
import '../../models/compatibility_profile.dart';
import '../../models/match_model.dart';
import '../../models/notification_preferences.dart';
import '../../models/questionnaire_model.dart';
import '../../models/subscription_model.dart';

class DemoStore {
  DemoStore._();

  static AppUser user = AppUser(
    id: 'demo_user',
    email: 'demo@duolynk.local',
    displayName: 'Avery',
    age: 29,
    gender: 'Woman',
    interestedIn: const ['Men'],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    country: 'United States',
    city: 'Chicago',
    bio:
        'Compatibility-first romantic, coffee loyalist, and believer in thoughtful conversation over endless swiping.',
    photoUrl: '',
    photoUrls: const [],
    isProfileComplete: true,
  );

  static NotificationPreferences notificationPreferences =
      const NotificationPreferences();

  static SubscriptionModel subscription = SubscriptionModel(
    id: 'demo_subscription',
    userId: 'demo_user',
    tier: SubscriptionTier.premium,
    platform: SubscriptionPlatform.unknown,
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
    entitlementId: 'premium',
    productId: 'duolynk_premium_annual',
  );

  static final Map<String, QuestionnaireModel> questionnaires = {};

  static final AppUser _matchUser = AppUser(
    id: 'demo_match_1',
    email: 'sophia@duolynk.local',
    displayName: 'Sophia',
    age: 28,
    gender: 'Woman',
    interestedIn: const ['Men'],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    country: 'United States',
    city: 'Chicago',
    bio:
        'Bookmarked restaurants, camera-roll sunsets, and the kind of person who actually wants something real.',
    photoUrl: '',
    photoUrls: const [],
    isProfileComplete: true,
  );

  static CompatibilityMatchResult weeklyMatch = CompatibilityMatchResult(
    profile: CompatibilityProfile(
      user: _matchUser,
      interests: const ['Travel', 'Reading', 'Photography', 'Music'],
      lifestyleAnswers: const {
        'drinking': 'Sometimes',
        'exerciseFrequency': '3-4 times a week',
      },
      relationshipGoalAnswers: const {
        'marriage': 'Yes',
        'longTermRelationship': 'Yes',
      },
      personalityAnswers: const {
        'communicationStyle': 'Direct and warm',
        'planningVsSpontaneous': 'Balanced',
      },
      preferenceAnswers: const {},
    ),
    compatibilityScore: 91,
    scope: MatchSearchScope.nearby,
    insights: const [
      CompatibilityInsight(
        label: 'Interests',
        score: 92,
        description: 'Shared interests include travel, reading, and music.',
      ),
      CompatibilityInsight(
        label: 'Relationship Goals',
        score: 95,
        description: 'You both show strong alignment on long-term commitment.',
      ),
      CompatibilityInsight(
        label: 'Lifestyle',
        score: 86,
        description: 'Your day-to-day lifestyle answers are closely aligned.',
      ),
      CompatibilityInsight(
        label: 'Personality',
        score: 88,
        description: 'You communicate in similar, emotionally clear ways.',
      ),
    ],
    categoryScores: const {
      'interests': 92,
      'lifestyle': 86,
      'relationshipGoals': 95,
      'personality': 88,
      'location': 100,
    },
  );

  static MatchModel activeMatch = MatchModel(
    id: 'demo_match_record',
    userId: 'demo_user',
    partnerId: 'demo_match_1',
    compatibilityScore: 91,
    status: MatchStatus.active,
    compatibilityReasons: weeklyMatch.insights,
    createdAt: DateTime(2026, 1, 1),
    expiresAt: DateTime(2026, 12, 31),
    chatId: 'demo_chat_1',
    pairKey: 'demo_match_1_demo_user',
    generatedBySystem: true,
    generatedForTier: 'premium',
    searchScope: MatchSearchScope.nearby.name,
    weekKey: 'demo_week',
  );

  static ChatModel chat = ChatModel(
    id: 'demo_chat_1',
    matchId: 'demo_match_record',
    pairKey: 'demo_match_1_demo_user',
    memberIds: const ['demo_user', 'demo_match_1'],
    memberSnapshots: {
      'demo_user': ChatParticipantSnapshot(
        id: 'demo_user',
        displayName: 'Avery',
        country: 'United States',
        age: 29,
      ),
      'demo_match_1': ChatParticipantSnapshot(
        id: 'demo_match_1',
        displayName: 'Sophia',
        country: 'United States',
        age: 28,
      ),
    },
    compatibilityScore: 91,
    compatibilityReasons: weeklyMatch.insights,
    lastMessage: 'I love that we both prefer intentional dating.',
    lastMessageType: ChatMessageType.text,
    lastMessageAt: DateTime(2026, 1, 1, 10, 15),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1, 10, 15),
    lastReadAtByUser: {
      'demo_user': DateTime(2026, 1, 1, 10, 16),
      'demo_match_1': DateTime(2026, 1, 1, 10, 16),
    },
    typingByUser: const {},
    lastMessageSenderId: 'demo_match_1',
  );

  static List<ChatMessageModel> messages = [
    ChatMessageModel(
      id: 'demo_message_1',
      chatId: 'demo_chat_1',
      senderId: 'demo_match_1',
      text: 'I love that we both prefer intentional dating.',
      type: ChatMessageType.text,
      createdAt: DateTime(2026, 1, 1, 10, 15),
      readByUserIds: const ['demo_match_1', 'demo_user'],
    ),
  ];

  static Set<String> blockedUserIds = {};

  static void saveUser(AppUser nextUser) {
    user = nextUser.copyWith(updatedAt: DateTime.now());
  }

  static void saveQuestionnaire(QuestionnaireModel questionnaire) {
    questionnaires[questionnaire.id] = questionnaire;
  }

  static QuestionnaireModel? questionnaireById(String id) => questionnaires[id];

  static void addMessage(ChatMessageModel message) {
    messages = [...messages, message];
    chat = ChatModel(
      id: chat.id,
      matchId: chat.matchId,
      pairKey: chat.pairKey,
      memberIds: chat.memberIds,
      memberSnapshots: chat.memberSnapshots,
      compatibilityScore: chat.compatibilityScore,
      compatibilityReasons: chat.compatibilityReasons,
      lastMessage: message.type == ChatMessageType.image
          ? 'Photo'
          : message.text,
      lastMessageType: message.type,
      lastMessageAt: message.createdAt,
      createdAt: chat.createdAt,
      updatedAt: message.createdAt,
      lastReadAtByUser: {
        ...chat.lastReadAtByUser,
        message.senderId: message.createdAt,
      },
      typingByUser: const {},
      lastMessageSenderId: message.senderId,
    );
  }
}
