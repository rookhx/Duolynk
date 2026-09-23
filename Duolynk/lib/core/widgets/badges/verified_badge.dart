import 'package:flutter/material.dart';

import '../../../models/app_user.dart';
import '../../../theme/app_colors.dart';

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, required this.status, this.size = 18});

  final VerificationStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (status != VerificationStatus.verified) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: 'Verified profile',
      child: Icon(Icons.verified_rounded, size: size, color: AppColors.accent),
    );
  }
}
