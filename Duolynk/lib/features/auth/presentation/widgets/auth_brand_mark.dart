import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_gradients.dart';
import '../../../../theme/app_spacing.dart';

class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({
    super.key,
    this.compact = false,
    this.showTagline = true,
  });

  final bool compact;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final titleStyle = compact
        ? Theme.of(context).textTheme.headlineMedium
        : Theme.of(context).textTheme.displayMedium;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Hero(
          tag: 'duolynk-brand-mark',
          child: Container(
            width: compact ? 74 : 96,
            height: compact ? 74 : 96,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.primary,
              boxShadow: [
                BoxShadow(
                  color: Color(0x55B26BFF),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: compact ? 44 : 54,
                height: compact ? 44 : 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background.withValues(alpha: 0.18),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
        Text('Duolynk', style: titleStyle),
        if (showTagline) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Smart Connections. Real Compatibility.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}
