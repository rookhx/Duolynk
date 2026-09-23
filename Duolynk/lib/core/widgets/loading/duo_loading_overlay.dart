import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../cards/duo_glass_card.dart';
import 'duo_loading_indicator.dart';

class DuoLoadingOverlay extends StatelessWidget {
  const DuoLoadingOverlay({
    super.key,
    required this.child,
    required this.isVisible,
  });

  final Widget child;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isVisible)
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.background.withValues(alpha: 0.72),
              child: Center(
                child: SizedBox(
                  width: 180,
                  child: DuoGlassCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: const DuoLoadingIndicator(
                      label: 'Preparing foundation...',
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
