import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';

class PhotoPickerGrid extends StatelessWidget {
  const PhotoPickerGrid({
    super.key,
    required this.remotePhotoUrls,
    required this.localPhotos,
    required this.onAddPhotos,
    required this.onRemoveRemote,
    required this.onRemoveLocal,
    this.onMoveRemoteUp,
    this.onMoveRemoteDown,
  });

  final List<String> remotePhotoUrls;
  final List<Uint8List> localPhotos;
  final VoidCallback onAddPhotos;
  final ValueChanged<int> onRemoveRemote;
  final ValueChanged<int> onRemoveLocal;
  final ValueChanged<int>? onMoveRemoteUp;
  final ValueChanged<int>? onMoveRemoteDown;

  @override
  Widget build(BuildContext context) {
    final totalCount = remotePhotoUrls.length + localPhotos.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            ...remotePhotoUrls.asMap().entries.map(
              (entry) => _PhotoTile.network(
                imageUrl: entry.value,
                isPrimary: entry.key == 0,
                onRemove: () => onRemoveRemote(entry.key),
                onMoveUp: onMoveRemoteUp == null || entry.key == 0
                    ? null
                    : () => onMoveRemoteUp!(entry.key),
                onMoveDown:
                    onMoveRemoteDown == null ||
                        entry.key == remotePhotoUrls.length - 1
                    ? null
                    : () => onMoveRemoteDown!(entry.key),
              ),
            ),
            ...localPhotos.asMap().entries.map(
              (entry) => _PhotoTile.memory(
                bytes: entry.value,
                isPrimary:
                    totalCount > 0 && remotePhotoUrls.isEmpty && entry.key == 0,
                onRemove: () => onRemoveLocal(entry.key),
              ),
            ),
            if (totalCount < 6)
              _AddPhotoTile(onTap: onAddPhotos, remaining: 6 - totalCount),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Add up to 6 photos. Your first image becomes your primary profile photo.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap, required this.remaining});

  final VoidCallback onTap;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.large),
      onTap: onTap,
      child: Container(
        width: 108,
        height: 132,
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppRadii.large),
          border: Border.all(color: AppColors.cardStroke),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, color: AppColors.accent),
            const SizedBox(height: AppSpacing.sm),
            Text('Add photos', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$remaining left',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile.network({
    required this.imageUrl,
    required this.isPrimary,
    required this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
  }) : bytes = null;

  const _PhotoTile.memory({
    required this.bytes,
    required this.isPrimary,
    required this.onRemove,
  }) : imageUrl = null,
       onMoveUp = null,
       onMoveDown = null;

  final String? imageUrl;
  final Uint8List? bytes;
  final bool isPrimary;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 132,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.large),
            child: SizedBox.expand(
              child: imageUrl != null
                  ? Image.network(imageUrl!, fit: BoxFit.cover)
                  : Image.memory(bytes!, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xAA0A0A12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          if (onMoveUp != null || onMoveDown != null)
            Positioned(
              left: 8,
              top: 8,
              child: Row(
                children: [
                  if (onMoveUp != null)
                    _PhotoIconButton(
                      icon: Icons.keyboard_arrow_left_rounded,
                      onTap: onMoveUp!,
                    ),
                  if (onMoveDown != null)
                    _PhotoIconButton(
                      icon: Icons.keyboard_arrow_right_rounded,
                      onTap: onMoveDown!,
                    ),
                ],
              ),
            ),
          if (isPrimary)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xCC121220),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Primary',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoIconButton extends StatelessWidget {
  const _PhotoIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: const Color(0xAA0A0A12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}
