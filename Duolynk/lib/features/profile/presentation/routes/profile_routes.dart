import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_route_paths.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/profile_preview_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/safety_center_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/terms_screen.dart';
import '../../../onboarding/presentation/screens/optional_compatibility_screen.dart';

final List<RouteBase> profileRoutes = [
  GoRoute(
    path: AppRoutePaths.profile,
    pageBuilder: (context, state) =>
        _buildPage(state: state, child: const ProfileScreen()),
    routes: [
      GoRoute(
        path: 'edit',
        pageBuilder: (context, state) =>
            _buildPage(state: state, child: const ProfileSetupScreen()),
      ),
      GoRoute(
        path: 'preview',
        pageBuilder: (context, state) =>
            _buildPage(state: state, child: const ProfilePreviewScreen()),
      ),
      GoRoute(
        path: 'compatibility-profile',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const OptionalCompatibilityScreen(),
        ),
      ),
      GoRoute(
        path: 'settings',
        pageBuilder: (context, state) =>
            _buildPage(state: state, child: const SettingsScreen()),
        routes: [
          GoRoute(
            path: 'notifications',
            pageBuilder: (context, state) => _buildPage(
              state: state,
              child: const NotificationSettingsScreen(),
            ),
          ),
          GoRoute(
            path: 'safety',
            pageBuilder: (context, state) =>
                _buildPage(state: state, child: const SafetyCenterScreen()),
          ),
          GoRoute(
            path: 'privacy-policy',
            pageBuilder: (context, state) =>
                _buildPage(state: state, child: const PrivacyPolicyScreen()),
          ),
          GoRoute(
            path: 'terms',
            pageBuilder: (context, state) =>
                _buildPage(state: state, child: const TermsScreen()),
          ),
        ],
      ),
    ],
  ),
];

CustomTransitionPage<void> _buildPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 280),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );
    },
  );
}
