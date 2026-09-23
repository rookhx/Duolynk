class StoragePaths {
  const StoragePaths._();

  static String profilePhoto(String userId, String fileName) =>
      'users/$userId/profile/$fileName';

  static String chatAttachment(
    String conversationId,
    String messageId,
    String fileName,
  ) => 'conversations/$conversationId/messages/$messageId/$fileName';
}
