import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_environment.dart';
import '../../../../core/demo/demo_store.dart';
import '../../../../core/providers/app_startup_provider.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_session.dart';

final authSessionProvider = StreamProvider<AuthSession>((ref) {
  final startup = ref.watch(appStartupProvider);
  if (startup.isLoading) {
    return Stream.value(const AuthSession(user: null, isAuthenticated: false));
  }

  if (!AppEnvironment.firebaseEnabled) {
    return Stream.value(
      AuthSession(user: DemoStore.user, isAuthenticated: true),
    );
  }

  final repository = ref.watch(authRepositoryProvider);
  return repository.watchAuthState().map(
    (user) => AuthSession(user: user, isAuthenticated: user != null),
  );
});
