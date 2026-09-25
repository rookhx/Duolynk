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
      final onboardingTarget = _onboardingTargetFor(session?.user);

      if (!isAuthenticated) {
        return isAuthRoute ? null : AppRoutePaths.login;
      }

      if (isAuthRoute) {
        return needsOnboarding
            ? AppRoutePaths.onboarding
            : AppRoutePaths.matching;
      }

      if (needsOnboarding) {
        if (!_isOnboardingRoute(location)) {
          return onboardingTarget;
        }
        if (location == AppRoutePaths.onboarding &&
            onboardingTarget != AppRoutePaths.onboarding) {
          return onboardingTarget;
        }
        if (location != AppRoutePaths.onboarding &&
            onboardingTarget == AppRoutePaths.onboarding) {
          return AppRoutePaths.onboarding;
        }
      } else if (_isOnboardingRoute(location)) {
        return AppRoutePaths.matching;
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

bool _isOnboardingRoute(String location) => const {
  AppRoutePaths.onboarding,
  AppRoutePaths.questionnaireOne,
  AppRoutePaths.questionnaireTwo,
  AppRoutePaths.questionnaireThree,
  AppRoutePaths.questionnaireFour,
  AppRoutePaths.questionnaireFive,
}.contains(location);

String _onboardingTargetFor(user) {
  if (user == null || user.isLegacyCompletedProfile) {
    return AppRoutePaths.onboarding;
  }
  if (user.datingProfileComplete != true) {
    return AppRoutePaths.onboarding;
  }
  if (user.requiredCompatibilityComplete == true) {
    return AppRoutePaths.matching;
  }
  final step = user.onboardingStep;
  if (step is String && _isOnboardingRoute(step)) {
    return step;
  }
  return AppRoutePaths.questionnaireOne;
}
