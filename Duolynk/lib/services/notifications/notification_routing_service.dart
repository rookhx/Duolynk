import '../../core/routing/app_route_paths.dart';
import '../../models/duolynk_notification_type.dart';
import '../../models/match_model.dart';

enum NotificationRouteResolutionStatus { route, unavailable }

class NotificationRouteResolution {
  const NotificationRouteResolution.route(this.path)
    : status = NotificationRouteResolutionStatus.route,
      message = null;

  const NotificationRouteResolution.unavailable(this.message)
    : status = NotificationRouteResolutionStatus.unavailable,
      path = null;

  final NotificationRouteResolutionStatus status;
  final String? path;
  final String? message;
}

class NotificationRoutingService {
  const NotificationRoutingService();

  NotificationRouteResolution resolve({
    required DuolynkNotificationType type,
    required Map<String, dynamic> data,
    MatchModel? match,
  }) {
    switch (type) {
      case DuolynkNotificationType.curatedIntroduction:
      case DuolynkNotificationType.introductionReminder:
        if (match == null ||
            match.status == MatchStatus.expired ||
            match.status == MatchStatus.passed ||
            match.status == MatchStatus.blocked ||
            match.status == MatchStatus.unmatched ||
            match.status == MatchStatus.archived) {
          return const NotificationRouteResolution.unavailable(
            'This introduction is no longer available.',
          );
        }
        return const NotificationRouteResolution.route(AppRoutePaths.matching);
      case DuolynkNotificationType.mutualMatch:
        if (match == null ||
            match.status == MatchStatus.blocked ||
            match.status == MatchStatus.unmatched ||
            match.status == MatchStatus.archived) {
          return const NotificationRouteResolution.unavailable(
            'This match is no longer available.',
          );
        }
        return const NotificationRouteResolution.route(AppRoutePaths.matching);
      case DuolynkNotificationType.newMessage:
      case DuolynkNotificationType.lockedMatchMessage:
        if (match != null && !match.isConversationEligible) {
          return const NotificationRouteResolution.unavailable(
            'This conversation is no longer available.',
          );
        }
        final chatId = data['chatId'] as String?;
        if (chatId == null || chatId.isEmpty) {
          return const NotificationRouteResolution.route(AppRoutePaths.chat);
        }
        return NotificationRouteResolution.route(
          AppRoutePaths.chatThread(chatId),
        );
      case DuolynkNotificationType.accountSafety:
        return const NotificationRouteResolution.route(
          AppRoutePaths.safetyCenter,
        );
    }
  }
}
