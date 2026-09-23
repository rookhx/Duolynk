import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_shadows.dart';
import '../../../theme/app_spacing.dart';

enum DuoButtonVariant { primary, secondary, ghost }

class DuoButton extends StatelessWidget {
  const DuoButton({
    super.key,
    this.label,
    required this.onPressed,
    this.icon,
    this.variant = DuoButtonVariant.primary,
    this.isExpanded = true,
    this.isLoading = false,
    this.child,
  });

  final String? label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final DuoButtonVariant variant;
  final bool isExpanded;
  final bool isLoading;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final Widget buttonChild =
        child ??
        Row(
          mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ] else if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(label ?? ''),
          ],
        );

    final style = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      textStyle: Theme.of(context).textTheme.labelLarge,
    );

    if (variant == DuoButtonVariant.primary) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryStart, AppColors.primaryEnd],
          ),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: AppShadows.glow,
        ),
        child: FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: style.copyWith(
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
            shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
          child: buttonChild,
        ),
      );
    }

    if (variant == DuoButtonVariant.secondary) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          side: const BorderSide(color: AppColors.cardStroke),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          foregroundColor: AppColors.textPrimary,
          textStyle: Theme.of(context).textTheme.labelLarge,
        ),
        child: buttonChild,
      );
    }

    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        foregroundColor: AppColors.textSecondary,
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
      child: buttonChild,
    );
  }
}
