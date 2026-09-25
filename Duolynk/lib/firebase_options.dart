// Firebase configuration for project `duolynk-1af9b`, in the same shape the
// FlutterFire CLI generates. Values come from the registered Android and iOS
// apps (`firebase apps:sdkconfig`).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyANVklXIhH_1THehqF0sRxhudRrQko1qUw',
    appId: '1:329361016322:android:37656623376b6fc514091b',
    messagingSenderId: '329361016322',
    projectId: 'duolynk-1af9b',
    storageBucket: 'duolynk-1af9b.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyADUQEOwSW-Bv-R0SgQ_OK-rLvgIN3tp64',
    appId: '1:329361016322:ios:40e1b6e1d6912b9214091b',
    messagingSenderId: '329361016322',
    projectId: 'duolynk-1af9b',
    storageBucket: 'duolynk-1af9b.firebasestorage.app',
    iosBundleId: 'com.duolynk.app',
  );
}
