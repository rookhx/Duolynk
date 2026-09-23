import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_route_paths.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/splash_screen.dart';

final List<RouteBase> authRoutes = [
  GoRoute(
    path: AppRoutePaths.root,
    pageBuilder: (context, state) =>
        const NoTransitionPage(child: SplashScreen()),
  ),
  GoRoute(path: AppRoutePaths.auth, redirect: (_, _) => AppRoutePaths.login),
  GoRoute(
    path: AppRoutePaths.login,
    pageBuilder: (context, state) =>
        _buildAuthPage(state: state, child: const LoginScreen()),
  ),
  GoRoute(
    path: AppRoutePaths.register,
    pageBuilder: (context, state) =>
        _buildAuthPage(state: state, child: const RegisterScreen()),
  ),
  GoRoute(
    path: AppRoutePaths.forgotPassword,
    pageBuilder: (context, state) =>
        _buildAuthPage(state: state, child: const ForgotPasswordScreen()),
  ),
];

CustomTransitionPage<void> _buildAuthPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 360),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.03),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}
