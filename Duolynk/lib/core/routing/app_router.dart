import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/routes/auth_routes.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/chat/presentation/routes/chat_routes.dart';
import '../../features/matching/presentation/routes/matching_routes.dart';
import '../../features/onboarding/presentation/routes/onboarding_routes.dart';
import '../../features/profile/presentation/routes/profile_routes.dart';
import '../../features/subscription/presentation/routes/subscription_routes.dart';
import '../providers/app_startup_provider.dart';
import 'app_route_paths.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final startup = ref.watch(appStartupProvider);
  final authSession = ref.watch(authSessionProvider);

  return GoRouter(
    initialLocation: AppRoutePaths.root,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isAuthRoute =
          location == AppRoutePaths.auth ||
          location == AppRoutePaths.login ||
          location == AppRoutePaths.register ||
          location == AppRoutePaths.forgotPassword;

      if (location == AppRoutePaths.root) {
        return null;
      }

      if (startup.isLoading || authSession.isLoading) {
        return AppRoutePaths.root;
      }

      final session = authSession.valueOrNull;
      final isAuthenticated = session?.isAuthenticated ?? false;
      final needsOnboarding = session?.needsOnboarding ?? false;

      if (!isAuthenticated) {
        return isAuthRoute ? null : AppRoutePaths.login;
      }

      if (isAuthRoute) {
        return needsOnboarding
            ? AppRoutePaths.onboarding
            : AppRoutePaths.matching;
      }

      if (needsOnboarding && location != AppRoutePaths.onboarding) {
        return AppRoutePaths.onboarding;
      }

      return null;
    },
    routes: [
      ...authRoutes,
      ...onboardingRoutes,
      ...matchingRoutes,
      ...chatRoutes,
      ...profileRoutes,
      ...subscriptionRoutes,
    ],
  );
});
