import 'package:firebase_auth/firebase_auth.dart';
// ignore_for_file: sort_child_properties_last

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_route_paths.dart';
import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/fields/duo_text_field.dart';
import '../../../../theme/app_spacing.dart';
import '../controllers/auth_action_controller.dart';
import '../widgets/auth_link_row.dart';
import '../widgets/auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authAction = ref.watch(authActionControllerProvider);

    return AuthScaffold(
      showBackButton: true,
      title: 'Reset your password',
      subtitle:
          'We’ll send a secure reset link so you can get back to intentional connections quickly.',
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
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required.';
                }
                if (!value.contains('@')) {
                  return 'Enter a valid email.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submitReset(),
            ),
            const SizedBox(height: AppSpacing.xl),
            DuoButton(
              label: 'Send Reset Link',
              onPressed: _submitReset,
              isLoading: authAction.isLoading,
            ),
          ],
        ),
      ),
      footer: AuthLinkRow(
        prompt: 'Remembered your password?',
        label: 'Back to sign in',
        onTap: () => context.go(AppRoutePaths.login),
      ),
    );
  }

  Future<void> _submitReset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(authActionControllerProvider.notifier)
        .sendPasswordResetEmail(email: _emailController.text.trim());

    final state = ref.read(authActionControllerProvider);
    if (!mounted) {
      return;
    }

    if (state.hasError) {
      final error = state.error;
      final message =
          error is FirebaseAuthException && error.code == 'user-not-found'
          ? 'No account was found for that email.'
          : 'We could not send the reset link right now.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      ref.read(authActionControllerProvider.notifier).clearError();
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Password reset link sent.')));
    ref.read(authActionControllerProvider.notifier).clearError();
    context.go(AppRoutePaths.login);
  }
}
