import '../../../models/app_user.dart';

class AuthSession {
  const AuthSession({required this.user, required this.isAuthenticated});

  final AppUser? user;
  final bool isAuthenticated;

  bool get needsOnboarding =>
      isAuthenticated && !(user?.hasCompletedRequiredOnboarding ?? false);
}
