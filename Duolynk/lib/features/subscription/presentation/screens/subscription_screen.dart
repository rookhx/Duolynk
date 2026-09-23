import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../services/analytics/analytics_event_service.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../controllers/subscription_controller.dart';
import '../widgets/paywall_plan_card.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(const AnalyticsEventService().track('premium_paywall_viewed'));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionControllerProvider);

    return state.when(
      loading: () => const _SubscriptionLoadingView(),
      error: (error, stackTrace) => _SubscriptionErrorView(
        onRetry: () =>
            ref.read(subscriptionControllerProvider.notifier).refresh(),
      ),
      data: (data) => Scaffold(
        body: Stack(
          children: [
            const _SubscriptionBackground(),
            SafeArea(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(subscriptionControllerProvider.notifier).refresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  children: [
                    Text(
                      'Duolynk Premium',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'See more of your curated candidates and activate more mutual conversations each week.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _HeroCard(isPremium: data.status.hasPremiumAccess),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Premium Features',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _FeatureCard(
                      icon: Icons.favorite_rounded,
                      title: 'Full profiles for curated candidates',
                      description:
                          'Basic can unlock 1 full curated profile each week. Premium can view every legitimate curated profile in that weekly set.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _FeatureCard(
                      icon: Icons.lock_open_rounded,
                      title: '3 conversation activations weekly',
                      description:
                          'Basic includes 1 new activated mutual conversation each week. Premium includes up to 3.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _FeatureCard(
                      icon: Icons.restore_rounded,
                      title: 'Your matches stay yours',
                      description:
                          'Activated conversations stay available. Premium never changes compatibility scores or bypasses eligibility.',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (!data.revenueCatReady || data.plans.isEmpty)
                      const _UnavailableCard()
                    else ...[
                      Text(
                        'Choose Your Plan',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ...data.plans.map(
                        (plan) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: PaywallPlanCard(
                            plan: plan,
                            isSelected: data.selectedPlan?.id == plan.id,
                            onTap: () => ref
                                .read(subscriptionControllerProvider.notifier)
                                .selectPlan(plan.id),
                          ),
                        ),
                      ),
                    ],
                    if (data.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        data.errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFFF9BAF),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    DuoButton(
                      label: data.status.hasPremiumAccess
                          ? 'Premium Active'
                          : 'Continue with Premium',
                      isLoading: data.isBusy,
                      onPressed:
                          data.status.hasPremiumAccess ||
                              !data.revenueCatReady ||
                              data.selectedPlan == null
                          ? null
                          : () async {
                              unawaited(
                                const AnalyticsEventService().track(
                                  'premium_purchase_started',
                                ),
                              );
                              final success = await ref
                                  .read(subscriptionControllerProvider.notifier)
                                  .purchaseSelectedPlan();
                              if (context.mounted && success) {
                                unawaited(
                                  const AnalyticsEventService().track(
                                    'premium_access_activated',
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Premium unlocked. Your matching benefits are now active.',
                                    ),
                                  ),
                                );
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DuoButton(
                      label: 'Restore Purchases',
                      variant: DuoButtonVariant.secondary,
                      isLoading: data.isBusy,
                      onPressed: !data.revenueCatReady
                          ? null
                          : () async {
                              unawaited(
                                const AnalyticsEventService().track(
                                  'purchase_restore_started',
                                ),
                              );
                              final restored = await ref
                                  .read(subscriptionControllerProvider.notifier)
                                  .restorePurchases();
                              if (context.mounted && restored) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Purchase history restored successfully.',
                                    ),
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return DuoGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryStart, AppColors.primaryEnd],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isPremium ? 'Premium Active' : 'Compatibility-First Upgrade',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isPremium
                ? 'Your Premium access is active.'
                : 'Upgrade for full curated-profile access and more weekly conversation activations.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Everyone gets the same compatibility-first matching. Premium changes profile access and weekly conversation activation quantity, not match quality.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return DuoGlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primaryStart, AppColors.primaryEnd],
              ),
            ),
            child: Icon(icon, color: AppColors.textPrimary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
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
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard();

  @override
  Widget build(BuildContext context) {
    return DuoGlassCard(
      child: Text(
        'RevenueCat is not configured yet for this build. Add your API keys and offering products to enable purchasing.',
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _SubscriptionLoadingView extends StatelessWidget {
  const _SubscriptionLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Stack(
        children: [
          _SubscriptionBackground(),
          Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class _SubscriptionErrorView extends StatelessWidget {
  const _SubscriptionErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _SubscriptionBackground(),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: DuoGlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'We could not load premium plans.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DuoButton(label: 'Try Again', onPressed: onRetry),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionBackground extends StatelessWidget {
  const _SubscriptionBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.background),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -30,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x30FF3E9E),
                    Color(0x16B26BFF),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -130,
            left: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x247B2FFF),
                    Color(0x10FF3E9E),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
