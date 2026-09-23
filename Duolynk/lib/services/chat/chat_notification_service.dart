import '../../core/config/firestore_paths.dart';
import '../../models/app_user.dart';
import '../../models/chat_model.dart';
import '../../models/duolynk_notification_type.dart';
import '../../models/notification_job.dart';
import '../../models/notification_preferences.dart';
import '../firebase/firestore_service.dart';

class ChatNotificationService {
  const ChatNotificationService({required FirestoreService firestoreService})
    : _firestoreService = firestoreService;

  final FirestoreService _firestoreService;

  Future<void> queueIncomingMessageNotification({
    required String recipientUserId,
    required ChatModel conversation,
    required ChatParticipantSnapshot sender,
    required ChatMessageModel message,
    bool includeMessagePreview = true,
  }) async {
    final preferences = await _fetchPreferences(recipientUserId);
    final recipient = await _fetchUser(recipientUserId);
    if (recipient == null ||
        !recipient.canUseDatingFeatures ||
        !preferences.pushEnabled ||
        !preferences.messages) {
      return;
    }

    final jobRef = _firestoreService
        .collection(FirestorePaths.notificationJobs)
        .doc();

    final preview = includeMessagePreview
        ? (message.type == ChatMessageType.image
              ? 'sent you a photo'
              : message.text.trim())
        : 'Someone you matched with sent you a message.';

    final job = NotificationJob(
      id: jobRef.id,
      userId: recipientUserId,
      title: includeMessagePreview ? sender.displayName : 'Duolynk',
      body: preview.isEmpty ? 'sent you a message' : preview,
      type: includeMessagePreview
          ? DuolynkNotificationType.newMessage
          : DuolynkNotificationType.lockedMatchMessage,
      createdAt: DateTime.now().toUtc(),
      data: {
        'chatId': conversation.id,
        'matchId': conversation.matchId,
        'senderId': sender.id,
        'route': 'chat',
      },
    );

    await _firestoreService.setDocument(
      FirestorePaths.notificationJob(job.id),
      job.toMap(),
      merge: false,
    );
  }

  Future<NotificationPreferences> _fetchPreferences(String userId) async {
    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.userSetting(userId, 'notification_preferences'),
    );
    final data = snapshot.data();
    return NotificationPreferences.fromMap(data ?? const {});
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
}
