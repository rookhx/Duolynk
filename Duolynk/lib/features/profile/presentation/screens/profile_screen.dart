import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_route_paths.dart';
import '../../../../core/widgets/badges/verified_badge.dart';
import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../core/widgets/layout/duo_primary_scaffold.dart';
import '../../../../core/widgets/media/storage_aware_image.dart';
import '../../../../services/analytics/analytics_event_service.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../controllers/profile_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);

    return profileState.when(
      loading: () => const DuoPrimaryScaffold(
        currentIndex: 2,
        title: 'Profile',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => DuoPrimaryScaffold(
        currentIndex: 2,
        title: 'Profile',
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'We could not load your profile.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (state) {
        final user = state.user;
        if (user == null) {
          return const DuoPrimaryScaffold(
            currentIndex: 2,
            title: 'Profile',
            body: Center(child: Text('No signed-in profile found.')),
          );
        }

        final photo = user.photoUrls.isNotEmpty
            ? user.photoUrls.first
            : user.photoUrl;

        return DuoPrimaryScaffold(
          currentIndex: 2,
          title: 'Profile',
          actions: [
            IconButton(
              onPressed: () => context.push(AppRoutePaths.settings),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
          body: RefreshIndicator(
            onRefresh: () =>
                ref.read(profileControllerProvider.notifier).refreshProfile(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              children: [
                DuoGlassCard(
                  child: Column(
                    children: [
                      ClipOval(
                        child: Container(
                          width: 108,
                          height: 108,
                          color: AppColors.cardSurface,
                          alignment: Alignment.center,
                          child: photo != null && photo.isNotEmpty
                              ? StorageAwareImage(
                                  source: photo,
                                  fit: BoxFit.cover,
                                )
                              : Text(
                                  user.displayName.characters.first
                                      .toUpperCase(),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineLarge,
                                ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                      if (user.isDatingPaused) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Dating paused',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.accent),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        [
                              if (user.city?.trim().isNotEmpty ?? false)
                                user.city!,
                              if (user.country?.trim().isNotEmpty ?? false)
                                user.country!,
                            ].join(', ').isEmpty
                            ? 'Location pending'
                            : [
                                if (user.city?.trim().isNotEmpty ?? false)
                                  user.city!,
                                if (user.country?.trim().isNotEmpty ?? false)
                                  user.country!,
                              ].join(', '),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (user.bio?.trim().isNotEmpty ?? false) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          user.bio!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      DuoButton(
                        label: 'Edit Profile',
                        onPressed: () async {
                          await const AnalyticsEventService().track(
                            'dating_profile_edit_started',
                          );
                          if (context.mounted) {
                            context.push(AppRoutePaths.profileEdit);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                DuoGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compatibility Profile',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Answer optional questions to help Duolynk understand your matches in more detail.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: state.compatibilityCompletion,
                          minHeight: 10,
                          backgroundColor: AppColors.cardStroke,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${(state.compatibilityCompletion * 100).round()}% complete',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      DuoButton(
                        label: 'Improve Your Matches',
                        variant: DuoButtonVariant.secondary,
                        onPressed: () async {
                          await const AnalyticsEventService().track(
                            'compatibility_profile_edit_started',
                          );
                          if (context.mounted) {
                            context.push(AppRoutePaths.compatibilityProfile);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                DuoGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dating Profile',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: state.completion,
                          minHeight: 10,
                          backgroundColor: AppColors.cardStroke,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${(state.completion * 100).round()}% complete',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (user.profilePrompts.length < 3) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Add profile prompts to help your matches get to know you.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                DuoGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preferences',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ProfileRow(label: 'Gender', value: user.gender),
                      _ProfileRow(
                        label: 'Interested In',
                        value: user.interestedIn.isEmpty
                            ? 'Not set'
                            : user.interestedIn.join(', '),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
