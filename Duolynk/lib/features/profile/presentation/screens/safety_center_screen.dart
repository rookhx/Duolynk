import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../services/analytics/analytics_event_service.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';

class SafetyCenterScreen extends StatefulWidget {
  const SafetyCenterScreen({super.key});

  @override
  State<SafetyCenterScreen> createState() => _SafetyCenterScreenState();
}

class _SafetyCenterScreenState extends State<SafetyCenterScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(const AnalyticsEventService().track('safety_center_viewed'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: const [
          _SafetySection(
            title: 'Dating safely',
            items: [
              'Keep early conversations in Duolynk.',
              "Never send money to someone you haven't independently verified.",
              'Be cautious if someone quickly asks to move communication elsewhere.',
              'Meet in a public place for early dates.',
              "Tell someone you trust where you're going.",
              'Arrange your own transportation where possible.',
            ],
          ),
          SizedBox(height: AppSpacing.xl),
          _SafetySection(
            title: 'Report and block',
            items: [
              'You can report fake profiles, scams, harassment, underage concerns, stolen photos, spam, and other safety issues.',
              'Blocking stops contact and prevents future recommendations.',
              'Reports are private and are not shown to the reported member.',
            ],
          ),
          SizedBox(height: AppSpacing.xl),
          _SafetySection(
            title: 'Verification',
            items: [
              'Verification helps show that someone is the person in their photos.',
              'Duolynk has verification architecture ready, but live verification review is coming soon.',
              'A verified badge appears only after a trusted review marks the profile verified.',
            ],
          ),
          SizedBox(height: AppSpacing.xl),
          _EmergencyNote(),
        ],
      ),
    );
  }
}

class _SafetySection extends StatelessWidget {
  const _SafetySection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return DuoGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmergencyNote extends StatelessWidget {
  const _EmergencyNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'If you or someone else is in immediate danger, contact local emergency services.',
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
    );
  }
}
