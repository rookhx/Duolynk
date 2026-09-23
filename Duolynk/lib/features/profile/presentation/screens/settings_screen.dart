import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_route_paths.dart';
import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../services/analytics/analytics_event_service.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../matching/data/match_feedback_repository.dart';
import '../../../../models/app_user.dart';
import '../../data/profile_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<bool>? _personalizedMatchingFuture;
  Future<AppUser?>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _personalizedMatchingFuture = _loadPersonalizedMatching();
    _profileFuture = ref.read(profileRepositoryProvider).fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
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
                _SettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Edit Profile',
                  subtitle: 'Update your photos, bio, and personal details.',
                  onTap: () async {
                    await const AnalyticsEventService().track(
                      'dating_profile_edit_started',
                    );
                    if (context.mounted) {
                      context.push(AppRoutePaths.profileEdit);
                    }
                  },
                ),
                _SettingsTile(
                  icon: Icons.psychology_alt_outlined,
                  title: 'Compatibility Profile',
                  subtitle:
                      'Answer optional questions that can shape future recommendations.',
                  onTap: () async {
                    await const AnalyticsEventService().track(
                      'compatibility_profile_edit_started',
                    );
                    if (context.mounted) {
                      context.push(AppRoutePaths.compatibilityProfile);
                    }
                  },
                ),
                _SettingsTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notification Settings',
                  subtitle: 'Choose the alerts Duolynk can send you.',
                  onTap: () => context.push(AppRoutePaths.notificationSettings),
                ),
                _SettingsTile(
                  icon: Icons.shield_outlined,
                  title: 'Safety',
                  subtitle: 'Review dating safety guidance and report options.',
                  onTap: () => context.push(AppRoutePaths.safetyCenter),
                ),
                _SettingsTile(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Premium',
                  subtitle: 'Manage Duolynk Premium and paywall access.',
                  onTap: () => context.push(AppRoutePaths.subscription),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          DuoGlassCard(
            child: FutureBuilder<AppUser?>(
              future: _profileFuture,
              builder: (context, snapshot) {
                final user = snapshot.data;
                final isPaused = user?.isDatingPaused ?? false;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPaused
                              ? Icons.pause_circle_outline_rounded
                              : Icons.favorite_border_rounded,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            isPaused ? 'Dating paused' : 'Dating active',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      isPaused
                          ? 'Resume when you want Duolynk to include you in future curated introductions again.'
                          : 'Stop receiving new Duolynk introductions while keeping your profile, matches, and conversations.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Pausing dating does not cancel your Premium subscription.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DuoButton(
                      label: isPaused ? 'Resume Dating' : 'Pause Dating',
                      variant: isPaused
                          ? DuoButtonVariant.primary
                          : DuoButtonVariant.secondary,
                      onPressed:
                          snapshot.connectionState == ConnectionState.waiting
                          ? null
                          : isPaused
                          ? _resumeDating
                          : _confirmPauseDating,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          DuoGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile verification',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "Verification helps show that you're the person in your photos. Verified badges will appear only after trusted review. Verification is coming soon.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                DuoButton(
                  label: 'Verification Coming Soon',
                  variant: DuoButtonVariant.secondary,
                  onPressed: () async {
                    await const AnalyticsEventService().track(
                      'verification_info_viewed',
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          DuoGlassCard(
            child: FutureBuilder<bool>(
              future: _personalizedMatchingFuture,
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? false;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personalized matching',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Allow Duolynk to use your private match feedback to make small adjustments to future recommendation ranking.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Use private feedback for ranking'),
                      value: enabled,
                      onChanged:
                          snapshot.connectionState == ConnectionState.waiting
                          ? null
                          : (value) => _setPersonalizedMatching(value),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DuoButton(
                      label: 'Reset personalized matching',
                      variant: DuoButtonVariant.secondary,
                      onPressed: _resetPersonalizedMatching,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          DuoGlassCard(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'Review how your data is handled.',
                  onTap: () => context.push(AppRoutePaths.privacyPolicy),
                ),
                _SettingsTile(
                  icon: Icons.article_outlined,
                  title: 'Terms of Service',
                  subtitle: 'Read the terms for using Duolynk.',
                  onTap: () => context.push(AppRoutePaths.terms),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          DuoGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                DuoButton(
                  label: 'Sign Out',
                  variant: DuoButtonVariant.secondary,
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) {
                      context.go(AppRoutePaths.login);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                DuoButton(
                  label: 'Delete Account',
                  variant: DuoButtonVariant.ghost,
                  onPressed: () => _confirmDeletion(context, ref),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Deleting your account permanently removes your profile, questionnaires, saved settings, and active match history.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletion(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This action is permanent. Some providers may require a recent sign-in before account deletion can complete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await ref.read(profileRepositoryProvider).deleteCurrentAccount();
      if (context.mounted) {
        context.go(AppRoutePaths.login);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account deletion failed: $error')),
        );
      }
    }
  }

  Future<bool> _loadPersonalizedMatching() async {
    final settings = await ref
        .read(matchFeedbackRepositoryProvider)
        .fetchSettings();
    return settings.enabled;
  }

  Future<void> _confirmPauseDating() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pause new introductions?'),
        content: const Text(
          "You won't receive new Duolynk introductions. Your existing matches, conversations, profile, and compatibility answers stay saved. Premium billing is not automatically cancelled.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Pause Dating'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _pauseDating();
    }
  }

  Future<void> _pauseDating() async {
    await ref.read(profileRepositoryProvider).pauseDating();
    if (!mounted) {
      return;
    }
    setState(() {
      _profileFuture = ref.read(profileRepositoryProvider).fetchProfile();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Dating is paused.')));
  }

  Future<void> _resumeDating() async {
    await ref.read(profileRepositoryProvider).resumeDating();
    if (!mounted) {
      return;
    }
    setState(() {
      _profileFuture = ref.read(profileRepositoryProvider).fetchProfile();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'You are back. Duolynk can include you in future introductions again.',
        ),
      ),
    );
  }

  Future<void> _setPersonalizedMatching(bool enabled) async {
    await ref
        .read(matchFeedbackRepositoryProvider)
        .setPersonalizedMatchingEnabled(enabled);
    if (mounted) {
      setState(() {
        _personalizedMatchingFuture = Future.value(enabled);
      });
    }
  }

  Future<void> _resetPersonalizedMatching() async {
    await ref.read(matchFeedbackRepositoryProvider).resetPersonalizedMatching();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personalized matching has been reset.')),
      );
    }
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.accent),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
