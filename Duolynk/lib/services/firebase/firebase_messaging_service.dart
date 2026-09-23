import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_environment.dart';
import '../../models/firebase_device_token.dart';
import 'firebase_bootstrap_service.dart';
import 'firestore_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseBootstrapService.ensureInitialized();
}

class FirebaseMessagingService {
  FirebaseMessagingService({
    FirebaseMessaging? messaging,
    FirestoreService? firestoreService,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestoreService = firestoreService ?? FirestoreService();

  final FirebaseMessaging _messaging;
  final FirestoreService _firestoreService;

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<NotificationSettings> requestPermission() {
    return _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<String?> getToken() {
    if (kIsWeb && AppEnvironment.firebaseMessagingVapidKey.isNotEmpty) {
      return _messaging.getToken(
        vapidKey: AppEnvironment.firebaseMessagingVapidKey,
      );
    }

    return _messaging.getToken();
  }

  Stream<String> onTokenRefresh() => _messaging.onTokenRefresh;

  Stream<RemoteMessage> onNotificationOpenedApp() =>
      FirebaseMessaging.onMessageOpenedApp;

  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  Future<void> syncToken({
    required String userId,
    required String deviceId,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final payload = FirebaseDeviceToken(
      id: deviceId,
      token: token,
      platform: defaultTargetPlatform.name,
      createdAt: now,
      updatedAt: now,
    );

    await _firestoreService.setDocument(
      'users/$userId/devices/$deviceId',
      payload.toMap(),
    );
  }
}
