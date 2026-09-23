import '../../models/chat_model.dart';
import '../../models/match_model.dart';
import '../../models/app_user.dart';

class ConversationAccessService {
  const ConversationAccessService();

  bool canOpenConversationShell(MatchModel match) =>
      match.isConversationEligible;

  bool canSendMessage({bool? hasConversationAccess, bool? hasPremium}) =>
      hasConversationAccess ?? hasPremium ?? false;

  bool canSendMessageForAccount({
    bool? hasConversationAccess,
    bool? hasPremium,
    required AppUser user,
  }) {
    return (hasConversationAccess ?? hasPremium ?? false) &&
        user.canUseDatingFeatures;
  }

  bool canReadMessage({
    bool? hasConversationAccess,
    bool? hasPremium,
    required ChatMessageModel message,
    required String userId,
  }) {
    return (hasConversationAccess ?? hasPremium ?? false) ||
        message.senderId == userId;
  }

  String safePreview({
    bool? recipientHasConversationAccess,
    bool? recipientHasPremium,
    required ChatMessageModel message,
  }) {
    final hasAccess =
        recipientHasConversationAccess ?? recipientHasPremium ?? false;
    if (!hasAccess) {
      return 'You have a new message from a match.';
    }
    return message.type == ChatMessageType.image
        ? 'sent you a photo'
        : message.text.trim();
  }
}
