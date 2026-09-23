class FirestorePaths {
  const FirestorePaths._();

  static const String users = 'users';
  static const String matches = 'matches';
  static const String conversations = 'conversations';
  static const String notificationJobs = 'notification_jobs';
  static const String moderationReports = 'moderation_reports';

  static String user(String userId) => '$users/$userId';
  static String userDevices(String userId) => '${user(userId)}/devices';
  static String userDevice(String userId, String deviceId) =>
      '${userDevices(userId)}/$deviceId';
  static String userQuestionnaires(String userId) =>
      '${user(userId)}/questionnaires';
  static String userQuestionnaire(String userId, String questionnaireId) =>
      '${userQuestionnaires(userId)}/$questionnaireId';
  static String userSubscriptions(String userId) =>
      '${user(userId)}/subscriptions';
  static String userSubscription(String userId, String subscriptionId) =>
      '${userSubscriptions(userId)}/$subscriptionId';
  static String userSettings(String userId) => '${user(userId)}/settings';
  static String userSetting(String userId, String settingId) =>
      '${userSettings(userId)}/$settingId';
  static String userMatchFeedback(String userId) =>
      '${user(userId)}/matchFeedback';
  static String userMatchFeedbackItem(String userId, String feedbackId) =>
      '${userMatchFeedback(userId)}/$feedbackId';
  static String userBlocks(String userId) => '${user(userId)}/blocks';
  static String userBlock(String userId, String blockedUserId) =>
      '${userBlocks(userId)}/$blockedUserId';
  static String userProfileUnlocks(String userId) =>
      '${user(userId)}/profileUnlocks';
  static String userProfileUnlock(String userId, String unlockId) =>
      '${userProfileUnlocks(userId)}/$unlockId';
  static String userConversationActivations(String userId) =>
      '${user(userId)}/conversationActivations';
  static String userConversationActivation(
    String userId,
    String activationId,
  ) => '${userConversationActivations(userId)}/$activationId';
  static String match(String matchId) => '$matches/$matchId';
  static String notificationJob(String notificationJobId) =>
      '$notificationJobs/$notificationJobId';
  static String moderationReport(String reportId) =>
      '$moderationReports/$reportId';
  static String conversation(String conversationId) =>
      '$conversations/$conversationId';
  static String conversationMessages(String conversationId) =>
      '${conversation(conversationId)}/messages';
  static String conversationMessage(String conversationId, String messageId) =>
      '${conversationMessages(conversationId)}/$messageId';
}
