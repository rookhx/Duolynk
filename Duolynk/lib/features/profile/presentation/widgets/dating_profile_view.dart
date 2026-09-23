import 'package:flutter/material.dart';

import '../../../../core/config/profile_prompt_library.dart';
import '../../../../core/widgets/badges/verified_badge.dart';
import '../../../../core/widgets/media/storage_aware_image.dart';
import '../../../../models/app_user.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';

class DatingProfileView extends StatelessWidget {
  const DatingProfileView({
    super.key,
    required this.user,
    this.relationshipIntention = '',
    this.publicInterests = const [],
    this.showPreviewNotice = false,
  });

  final AppUser user;
  final String relationshipIntention;
  final List<String> publicInterests;
  final bool showPreviewNotice;

  @override
  Widget build(BuildContext context) {
    final photos = user.photoUrls.isNotEmpty
        ? user.photoUrls
        : [if (user.photoUrl?.trim().isNotEmpty ?? false) user.photoUrl!];
    final location = [
      if (user.city?.trim().isNotEmpty ?? false) user.city!,
      if (user.country?.trim().isNotEmpty ?? false) user.country!,
    ].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showPreviewNotice) ...[
          Text(
            'Profile preview',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Compatibility details are omitted here because this is your own profile preview.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        AspectRatio(
          aspectRatio: 0.92,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: photos.isEmpty
                ? Container(
                    color: AppColors.cardSurface,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_rounded,
                      size: 88,
                      color: AppColors.textSecondary,
                    ),
                  )
                : StorageAwareImage(source: photos.first, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Flexible(
              child: Text(
                '${user.displayName}, ${user.displayAge()}',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            VerifiedBadge(status: user.verificationStatus),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          location.isEmpty ? 'Location pending' : location,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
        if (relationshipIntention.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _InfoPill(
            icon: Icons.favorite_border_rounded,
            label: relationshipIntention,
          ),
        ],
        if (user.bio?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('About', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            user.bio!.trim(),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        if (user.profilePrompts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Profile prompts',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          ...user.profilePrompts.map(
            (prompt) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _PromptAnswerCard(
                promptId: prompt.promptId,
                answer: prompt.answer,
              ),
            ),
          ),
        ],
        if (publicInterests.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('Interests', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final interest in publicInterests.take(8))
                Chip(label: Text(interest)),
              if (publicInterests.length > 8)
                Chip(label: Text('+${publicInterests.length - 8} more')),
            ],
          ),
        ],
        if (photos.length > 1) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('More photos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: photos.length - 1,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: StorageAwareImage(
                  source: photos[index + 1],
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _PromptAnswerCard extends StatelessWidget {
  const _PromptAnswerCard({required this.promptId, required this.answer});

  final String promptId;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ProfilePromptLibrary.labelFor(promptId),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(answer, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.cardStroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: AppSpacing.xs),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}
