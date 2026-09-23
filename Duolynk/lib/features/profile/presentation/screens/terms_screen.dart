import 'package:flutter/material.dart';

import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../theme/app_spacing.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: const [
          _TermsSection(
            title: 'Eligibility',
            body:
                'You must be of legal age in your jurisdiction and provide truthful information when using Duolynk.',
          ),
          SizedBox(height: AppSpacing.md),
          _TermsSection(
            title: 'Respectful Use',
            body:
                'Harassment, impersonation, fraudulent activity, or abusive conduct may lead to removal and moderation reporting.',
          ),
          SizedBox(height: AppSpacing.md),
          _TermsSection(
            title: 'Subscriptions',
            body:
                'Premium plans renew according to the billing terms shown during purchase. Restores and entitlement handling are managed through the platform and RevenueCat integration.',
          ),
        ],
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DuoGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
