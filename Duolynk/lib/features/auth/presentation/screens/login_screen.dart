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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
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
      title: 'Welcome back',
      subtitle:
          'Pick up where thoughtful conversations and genuine compatibility left off.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                hintText: 'Your password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
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
                onFieldSubmitted: (_) => _submitEmailSignIn(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push(AppRoutePaths.forgotPassword),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              DuoButton(
                label: 'Sign In',
                onPressed: _submitEmailSignIn,
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
        prompt: 'New to Duolynk?',
        label: 'Create account',
        onTap: () => context.go(AppRoutePaths.register),
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

  Future<void> _submitEmailSignIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(authActionControllerProvider.notifier)
        .signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
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
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Those credentials did not match our records.';
        case 'network-request-failed':
          return 'We could not reach Firebase. Check your connection and try again.';
      }
    }
    return 'Something went wrong while signing you in.';
  }
}
