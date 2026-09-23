// ignore_for_file: sort_child_properties_last

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_route_paths.dart';
import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/fields/duo_text_field.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../controllers/auth_action_controller.dart';
import '../widgets/auth_divider.dart';
import '../widgets/auth_link_row.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_social_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authAction = ref.watch(authActionControllerProvider);
    final appleAvailable = ref.watch(appleSignInAvailableProvider);
    final isLoading = authAction.isLoading;

    return AuthScaffold(
      showBackButton: true,
      title: 'Create your account',
      subtitle:
          'Start with a profile built for compatibility, intention, and lasting connection.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DuoTextField(
                controller: _nameController,
                label: 'Full name',
                hintText: 'How should your match know you?',
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Your name helps personalize your profile.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              DuoTextField(
                controller: _emailController,
                label: 'Email',
                hintText: 'name@example.com',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: _validateEmail,
              ),
              const SizedBox(height: AppSpacing.md),
              DuoTextField(
                controller: _passwordController,
                label: 'Password',
                hintText: 'Create a secure password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
                validator: _validatePassword,
                onFieldSubmitted: (_) => _submitRegistration(),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'By continuing, you agree to a more intentional dating experience grounded in authenticity and respect.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              DuoButton(
                label: 'Create Account',
                onPressed: _submitRegistration,
                isLoading: isLoading,
              ),
              const SizedBox(height: AppSpacing.xl),
              const AuthDivider(),
              const SizedBox(height: AppSpacing.xl),
              AuthSocialButton(
                label: 'Continue with Google',
                onPressed: _handleGoogleSignIn,
                isLoading: isLoading,
                leading: _socialMonogram('G'),
              ),
              if (appleAvailable.valueOrNull == true) ...[
                const SizedBox(height: AppSpacing.md),
                AuthSocialButton(
                  label: 'Continue with Apple',
                  onPressed: _handleAppleSignIn,
                  isLoading: isLoading,
                  leading: const Icon(
                    Icons.apple_rounded,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      footer: AuthLinkRow(
        prompt: 'Already have an account?',
        label: 'Sign in',
        onTap: () => context.go(AppRoutePaths.login),
      ),
    );
  }

  Widget _socialMonogram(String text) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.textPrimary,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.background,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(authActionControllerProvider.notifier)
        .registerWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          displayName: _nameController.text.trim(),
        );
    _showAuthErrorIfNeeded();
  }

  Future<void> _handleGoogleSignIn() async {
    await ref.read(authActionControllerProvider.notifier).signInWithGoogle();
    _showAuthErrorIfNeeded();
  }

  Future<void> _handleAppleSignIn() async {
    await ref.read(authActionControllerProvider.notifier).signInWithApple();
    _showAuthErrorIfNeeded();
  }

  void _showAuthErrorIfNeeded() {
    final state = ref.read(authActionControllerProvider);
    if (!mounted || !state.hasError) {
      return;
    }
    final message = _friendlyMessage(state.error);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    ref.read(authActionControllerProvider.notifier).clearError();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required.';
    }
    if (!value.contains('@')) {
      return 'Enter a valid email.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < 8) {
      return 'Use at least 8 characters.';
    }
    return null;
  }

  String _friendlyMessage(Object? error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'Choose a stronger password.';
        case 'network-request-failed':
          return 'We could not reach Firebase. Check your connection and try again.';
      }
    }
    return 'Something went wrong while creating your account.';
  }
}
