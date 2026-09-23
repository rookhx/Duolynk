import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_providers.dart';
import '../../services/firebase/firebase_bootstrap_service.dart';
import '../../services/firebase/firebase_messaging_service.dart';
import '../../services/revenuecat/revenuecat_service.dart';
import '../../services/storage/local_storage_service.dart';

final localStorageServiceProvider = Provider<LocalStorageService>(
  (ref) => const LocalStorageService(),
);

final firebaseBootstrapServiceProvider = Provider<FirebaseBootstrapService>(
  (ref) => const FirebaseBootstrapService(),
);

final revenueCatServiceProvider = Provider<RevenueCatService>(
  (ref) => const RevenueCatService(),
);

final firebaseMessagingBootstrapProvider = Provider<FirebaseMessagingService>(
  (ref) => ref.watch(firebaseMessagingServiceProvider),
);

final appStartupProvider = AsyncNotifierProvider<AppStartupController, void>(
  AppStartupController.new,
);

class AppStartupController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    await ref.read(localStorageServiceProvider).initialize();
    await ref.read(firebaseBootstrapServiceProvider).initialize();
    await ref.read(firebaseMessagingBootstrapProvider).initialize();
    await ref.read(revenueCatServiceProvider).initialize();
  }
}
