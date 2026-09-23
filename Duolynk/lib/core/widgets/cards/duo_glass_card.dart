import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_gradients.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_shadows.dart';
import '../../../theme/app_spacing.dart';

class DuoGlassCard extends StatelessWidget {
  const DuoGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadii.large,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            gradient: AppGradients.cardHighlight,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.cardStroke),
            boxShadow: AppShadows.soft,
          ),
          child: child,
        ),
      ),
    );
  }
}
