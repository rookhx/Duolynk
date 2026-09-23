import 'package:flutter/material.dart';

import '../../../../core/widgets/media/storage_aware_image.dart';
import '../../../../theme/app_colors.dart';

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 28,
  });

  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'D' : name.trim().characters.first;

    return ClipOval(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: AppColors.cardSurface,
        alignment: Alignment.center,
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? StorageAwareImage(source: photoUrl!, fit: BoxFit.cover)
            : Text(
                initial.toUpperCase(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
      ),
    );
  }
}
