import 'package:flutter/material.dart';

import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';

class OnboardingProgressCard extends StatelessWidget {
  const OnboardingProgressCard({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.completionPercent,
  });

  final int step;
  final int totalSteps;
  final int completionPercent;

  @override
  Widget build(BuildContext context) {
    return DuoGlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Step $step of $totalSteps',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Spacer(),
              Text(
                '$completionPercent% complete',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: step / totalSteps,
              minHeight: 8,
              backgroundColor: AppColors.cardStroke,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
