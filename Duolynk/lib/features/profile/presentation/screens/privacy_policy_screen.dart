import 'package:flutter/material.dart';

import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../theme/app_spacing.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: const [
          _LegalSection(
            title: 'Overview',
            body:
                'Duolynk collects profile details, questionnaire answers, subscription status, and messaging activity to deliver compatibility-first matchmaking and in-app conversations.',
          ),
          SizedBox(height: AppSpacing.md),
          _LegalSection(
            title: 'How We Use Data',
            body:
                'We use your information to calculate compatibility, generate weekly matches, personalize premium features, and support trust and safety reviews when reports are submitted.',
          ),
          SizedBox(height: AppSpacing.md),
          _LegalSection(
            title: 'Your Controls',
            body:
                'You can update your profile, change notification preferences, block members, report unsafe behavior, and request account deletion from the settings area.',
          ),
        ],
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.title, required this.body});

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
