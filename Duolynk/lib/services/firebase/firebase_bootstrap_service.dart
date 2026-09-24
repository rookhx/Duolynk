import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_environment.dart';
import '../../firebase_options.dart';

class FirebaseBootstrapService {
  const FirebaseBootstrapService();

  Future<bool> initialize() async {
    if (!AppEnvironment.firebaseEnabled) {
      return false;
    }

    await ensureInitialized();
    return true;
  }

  static Future<FirebaseApp?> ensureInitialized() async {
    if (!AppEnvironment.firebaseEnabled) {
      return null;
    }

    if (Firebase.apps.isNotEmpty) {
      return Firebase.apps.first;
    }

    final options = _firebaseOptions;

    // --dart-define values override the checked-in config for the platform.
    return Firebase.initializeApp(
      options: options ?? DefaultFirebaseOptions.currentPlatform,
    );
  }

  static FirebaseOptions? get _firebaseOptions {
    if (AppEnvironment.firebaseWebApiKey.isEmpty ||
        AppEnvironment.firebaseAppId.isEmpty ||
        AppEnvironment.firebaseMessagingSenderId.isEmpty ||
        AppEnvironment.firebaseProjectId.isEmpty) {
      return null;
    }

    return FirebaseOptions(
      apiKey: AppEnvironment.firebaseWebApiKey,
      appId: AppEnvironment.firebaseAppId,
      messagingSenderId: AppEnvironment.firebaseMessagingSenderId,
      projectId: AppEnvironment.firebaseProjectId,
      authDomain: AppEnvironment.firebaseAuthDomain.isEmpty
          ? null
          : AppEnvironment.firebaseAuthDomain,
      storageBucket: AppEnvironment.firebaseStorageBucket.isEmpty
          ? null
          : AppEnvironment.firebaseStorageBucket,
      iosBundleId: AppEnvironment.firebaseIosBundleId.isEmpty
          ? null
          : AppEnvironment.firebaseIosBundleId,
      iosClientId: AppEnvironment.firebaseIosClientId.isEmpty
          ? null
          : AppEnvironment.firebaseIosClientId,
      androidClientId: !kIsWeb && AppEnvironment.firebaseAndroidClientId.isEmpty
          ? null
          : AppEnvironment.firebaseAndroidClientId,
      measurementId: AppEnvironment.firebaseMeasurementId.isEmpty
          ? null
          : AppEnvironment.firebaseMeasurementId,
    );
  }
}
