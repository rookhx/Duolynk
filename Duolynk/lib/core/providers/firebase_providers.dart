import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/chat/chat_notification_service.dart';
import '../../services/firebase/firebase_auth_service.dart';
import '../../services/firebase/firebase_messaging_service.dart';
import '../../services/firebase/firebase_storage_service.dart';
import '../../services/firebase/firestore_service.dart';
import '../../services/matching/match_notification_service.dart';

final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(),
);

final firebaseAuthServiceProvider = Provider<FirebaseAuthService>(
  (ref) => FirebaseAuthService(),
);

final firebaseStorageServiceProvider = Provider<FirebaseStorageService>(
  (ref) => FirebaseStorageService(),
);

final firebaseMessagingServiceProvider = Provider<FirebaseMessagingService>(
  (ref) => FirebaseMessagingService(
    firestoreService: ref.watch(firestoreServiceProvider),
  ),
);

final matchNotificationServiceProvider = Provider<MatchNotificationService>(
  (ref) => MatchNotificationService(
    firestoreService: ref.watch(firestoreServiceProvider),
  ),
);

final chatNotificationServiceProvider = Provider<ChatNotificationService>(
  (ref) => ChatNotificationService(
    firestoreService: ref.watch(firestoreServiceProvider),
  ),
);
