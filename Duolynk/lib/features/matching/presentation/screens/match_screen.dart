import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_route_paths.dart';
import '../../../../core/config/profile_prompt_library.dart';
import '../../../../core/widgets/badges/verified_badge.dart';
import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../core/widgets/compatibility/compatibility_meter.dart';
import '../../../../core/widgets/layout/duo_primary_scaffold.dart';
import '../../../../core/widgets/media/storage_aware_image.dart';
import '../../../../models/match_model.dart';
import '../../../../services/access/trusted_access_repository.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/presentation/widgets/user_safety_actions.dart';
import '../../../subscription/data/subscription_repository.dart';
import '../../data/match_feedback_repository.dart';
import '../../data/matching_repository.dart';
import '../../domain/curated_match_suggestion.dart';
import '../controllers/weekly_match_controller.dart';
import '../widgets/match_feedback_sheet.dart';

class MatchScreen extends ConsumerWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weeklyMatchControllerProvider);
    final subscription = ref.watch(subscriptionStatusProvider);

    return state.when(
      loading: () => const _MatchLoadingView(),
      error: (error, stackTrace) => _MatchErrorView(
        onRetry: () =>
            ref.read(weeklyMatchControllerProvider.notifier).refresh(),
      ),
      data: (data) => data.recommendations.isEmpty
          ? _EmptyMatchView(
              onRefresh: () =>
                  ref.read(weeklyMatchControllerProvider.notifier).refresh(),
            )
          : _CandidateBatchView(
              suggestions: data.recommendations,
              hasPremium: subscription.valueOrNull?.hasPremiumAccess ?? false,
              profileRepository: ref.read(profileRepositoryProvider),
              feedbackRepository: ref.read(matchFeedbackRepositoryProvider),
              onRefresh: () =>
                  ref.read(weeklyMatchControllerProvider.notifier).refresh(),
            ),
    );
  }
}

class _CandidateBatchView extends ConsumerStatefulWidget {
  const _CandidateBatchView({
    required this.suggestions,
    required this.hasPremium,
    required this.profileRepository,
    required this.feedbackRepository,
    required this.onRefresh,
  });

  final List<CuratedMatchSuggestion> suggestions;
  final bool hasPremium;
  final ProfileRepository profileRepository;
  final MatchFeedbackRepository feedbackRepository;
  final Future<void> Function() onRefresh;

  @override
  ConsumerState<_CandidateBatchView> createState() =>
      _CandidateBatchViewState();
}

class _CandidateBatchViewState extends ConsumerState<_CandidateBatchView> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex.clamp(
      0,
      widget.suggestions.length - 1,
    );
    final suggestion = widget.suggestions[selectedIndex];
    return _SingleMatchView(
      suggestion: suggestion,
      suggestions: widget.suggestions,
      selectedIndex: selectedIndex,
      hasPremium: widget.hasPremium,
      profileRepository: widget.profileRepository,
      feedbackRepository: widget.feedbackRepository,
      onSelectSuggestion: (index) => setState(() => _selectedIndex = index),
      onUnmatch: () =>
          ref.read(matchingRepositoryProvider).unmatch(suggestion.match.id),
      onRefresh: widget.onRefresh,
      onInterested: () => ref
          .read(weeklyMatchControllerProvider.notifier)
          .markInterested(suggestion.match.id),
      onPass: () => ref
          .read(weeklyMatchControllerProvider.notifier)
          .pass(suggestion.match.id),
    );
  }
}

class _SingleMatchView extends StatelessWidget {
  const _SingleMatchView({
    required this.suggestion,
    required this.suggestions,
    required this.selectedIndex,
    required this.hasPremium,
    required this.profileRepository,
    required this.feedbackRepository,
    required this.onSelectSuggestion,
    required this.onUnmatch,
    required this.onRefresh,
    required this.onInterested,
    required this.onPass,
  });

  final CuratedMatchSuggestion suggestion;
  final List<CuratedMatchSuggestion> suggestions;
  final int selectedIndex;
  final bool hasPremium;
  final ProfileRepository profileRepository;
  final MatchFeedbackRepository feedbackRepository;
  final ValueChanged<int> onSelectSuggestion;
  final Future<MatchModel> Function() onUnmatch;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onInterested;
  final Future<void> Function() onPass;

  @override
  Widget build(BuildContext context) {
    final match = suggestion.match;
    final user = suggestion.partner;
    final photo = user.photoUrls.isNotEmpty
        ? user.photoUrls.first
        : user.photoUrl;
    final country = user.country?.trim().isNotEmpty == true
        ? user.country!
        : 'Location pending';
    final hasFullProfileAccess =
        hasPremium ||
        match.isConversationEligible ||
        suggestion.hasProfileUnlock;

    return DuoPrimaryScaffold(
      currentIndex: 0,
      title: 'Curated Candidates',
      actions: [
        IconButton(
          onPressed: () => showUserSafetyActions(
            context: context,
            repository: profileRepository,
            targetUserId: user.id,
            targetName: user.displayName,
            source: 'match_screen',
            onUnmatch: match.isConversationEligible
                ? () async {
                    final updatedMatch = await onUnmatch();
                    if (context.mounted) {
                      await showMatchFeedbackSheet(
                        context: context,
                        repository: feedbackRepository,
                        match: updatedMatch,
                      );
                    }
                  }
                : null,
            onCompleted: () {
              onRefresh();
            },
          ),
          icon: const Icon(Icons.shield_outlined),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'Your weekly candidates are selected for eligibility and compatibility. Choose Interested or Pass deliberately.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            if (suggestions.length > 1) ...[
              const SizedBox(height: AppSpacing.lg),
              _CandidateSelector(
                suggestions: suggestions,
                selectedIndex: selectedIndex,
                onSelected: onSelectSuggestion,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            DuoGlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    child: AspectRatio(
                      aspectRatio: 0.92,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (hasFullProfileAccess &&
                              photo != null &&
                              photo.isNotEmpty)
                            StorageAwareImage(source: photo, fit: BoxFit.cover)
                          else
                            Container(
                              color: const Color(0x22121220),
                              alignment: Alignment.center,
                              child: Icon(
                                hasFullProfileAccess
                                    ? Icons.person_rounded
                                    : Icons.lock_rounded,
                                size: 88,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Color(0xD90A0A12)],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 20,
                            right: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x99121220),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.cardStroke),
                              ),
                              child: Text(
                                '${match.compatibilityScore}% Compatible',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: AppColors.textPrimary),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 24,
                            right: 24,
                            bottom: 24,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        hasFullProfileAccess
                                            ? '${user.displayName}, ${user.displayAge()}'
                                            : 'Curated candidate',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineLarge,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    VerifiedBadge(
                                      status: user.verificationStatus,
                                      size: 22,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.public_rounded,
                                      size: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      country,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.textPrimary
                                                .withValues(alpha: 0.82),
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: CompatibilityMeter(
                            score: match.compatibilityScore,
                            size: 164,
                          ),
                        ),
                        if (suggestion.relationshipIntention
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _RelationshipIntentionPill(
                            label: suggestion.relationshipIntention,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          hasFullProfileAccess
                              ? 'Why Duolynk matched you'
                              : 'Compatibility teaser',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ..._buildReasonTiles(context, match),
                        const SizedBox(height: AppSpacing.xl),
                        if (hasFullProfileAccess)
                          _HumanProfileSection(suggestion: suggestion)
                        else
                          _LockedProfileSection(
                            candidateUid: user.id,
                            onUnlocked: onRefresh,
                          ),
                        const SizedBox(height: AppSpacing.xl),
                        if (hasFullProfileAccess)
                          _DetailedReportSection(
                            match: match,
                            showProfilePrompt:
                                match.dataCompleteness > 0 &&
                                match.dataCompleteness < 0.45,
                          ),
                        const SizedBox(height: AppSpacing.xl),
                        _SuggestionActionSection(
                          match: match,
                          hasPremium: hasPremium,
                          onInterested: onInterested,
                          onPass: onPass,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReasonTiles(BuildContext context, MatchModel match) {
    final selectedInsights = [...match.compatibilityReasons]
      ..sort((a, b) {
        final priorityCompare = a.displayPriority.compareTo(b.displayPriority);
        if (priorityCompare != 0) {
          return priorityCompare;
        }
        return b.score.compareTo(a.score);
      });

    return selectedInsights.take(5).map<Widget>((insight) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.cardStroke),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.primaryStart, AppColors.primaryEnd],
                  ),
                ),
                child: const Icon(
                  _InsightIcon.iconData,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      insight.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class _CandidateSelector extends StatelessWidget {
  const _CandidateSelector({
    required this.suggestions,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<CuratedMatchSuggestion> suggestions;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          final isSelected = index == selectedIndex;
          return ChoiceChip(
            selected: isSelected,
            onSelected: (_) => onSelected(index),
            label: Text(
              '${suggestion.match.compatibilityScore}% candidate ${index + 1}',
            ),
          );
        },
      ),
    );
  }
}

class _LockedProfileSection extends ConsumerStatefulWidget {
  const _LockedProfileSection({
    required this.candidateUid,
    required this.onUnlocked,
  });

  final String candidateUid;
  final Future<void> Function() onUnlocked;

  @override
  ConsumerState<_LockedProfileSection> createState() =>
      _LockedProfileSectionState();
}

class _LockedProfileSectionState extends ConsumerState<_LockedProfileSection> {
  bool _isUnlocking = false;

  @override
  Widget build(BuildContext context) {
    return DuoGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Profile locked',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Basic can express Interested or Pass from the compatibility teaser without spending a profile unlock. Premium reveals all legitimate curated profiles.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          DuoButton(
            label: 'Unlock Profile',
            variant: DuoButtonVariant.secondary,
            isLoading: _isUnlocking,
            onPressed: _isUnlocking ? null : () => _unlock(context),
          ),
        ],
      ),
    );
  }

  Future<void> _unlock(BuildContext context) async {
    setState(() => _isUnlocking = true);
    try {
      final result = await ref
          .read(trustedAccessRepositoryProvider)
          .unlockCandidateProfile(candidateUid: widget.candidateUid);
      if (!context.mounted) {
        return;
      }
      if (result.succeeded) {
        await widget.onUnlocked();
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Profile unlocked.')));
        }
      } else if (result.status == 'quotaReached') {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Profile unlock used'),
            content: const Text(
              "You've used this week's Basic profile unlock. Premium reveals all of your curated profiles.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Not now'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutePaths.subscription);
                },
                child: const Text('View Premium'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('We could not unlock that profile.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('We could not unlock that profile.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUnlocking = false);
      }
    }
  }
}

class _HumanProfileSection extends StatelessWidget {
  const _HumanProfileSection({required this.suggestion});

  final CuratedMatchSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final user = suggestion.partner;
    final photos = user.photoUrls.length > 1
        ? user.photoUrls.skip(1).toList()
        : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (user.bio?.trim().isNotEmpty ?? false) ...[
          Text(
            'About ${user.displayName}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
              child: Container(
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
                      ProfilePromptLibrary.labelFor(prompt.promptId),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      prompt.answer,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (suggestion.publicInterests.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('Interests', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final interest in suggestion.publicInterests.take(8))
                Chip(label: Text(interest)),
              if (suggestion.publicInterests.length > 8)
                Chip(
                  label: Text('+${suggestion.publicInterests.length - 8} more'),
                ),
            ],
          ),
        ],
        if (photos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('More photos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: photos.length,
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
                  source: photos[index],
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

class _RelationshipIntentionPill extends StatelessWidget {
  const _RelationshipIntentionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
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
            const Icon(
              Icons.favorite_border_rounded,
              size: 18,
              color: AppColors.accent,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class _DetailedReportSection extends StatelessWidget {
  const _DetailedReportSection({
    required this.match,
    required this.showProfilePrompt,
  });

  final MatchModel match;
  final bool showProfilePrompt;

  @override
  Widget build(BuildContext context) {
    final categoryRows = _categoryRows(match);

    return DuoGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your compatibility',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A simple look at the areas that shaped this introduction.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...categoryRows.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _ReportScoreRow(label: entry.key, score: entry.value),
            ),
          ),
          if (showProfilePrompt) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Want even better matches? Complete more of your compatibility profile.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  List<MapEntry<String, int>> _categoryRows(MatchModel match) {
    final labels = const {
      'relationshipGoals': 'Relationship goals',
      'interests': 'Interests',
      'lifestyle': 'Lifestyle',
      'personality': 'Personality',
      'location': 'Location',
    };
    if (match.categoryScores.isNotEmpty) {
      return labels.entries
          .where((entry) => match.categoryScores.containsKey(entry.key))
          .map(
            (entry) => MapEntry(entry.value, match.categoryScores[entry.key]!),
          )
          .toList();
    }
    return match.compatibilityReasons
        .map((reason) => MapEntry(reason.label, reason.score))
        .toList();
  }
}

class _InsightIcon {
  const _InsightIcon._();

  static const IconData iconData = Icons.auto_awesome_rounded;
}

class _SuggestionActionSection extends StatefulWidget {
  const _SuggestionActionSection({
    required this.match,
    required this.hasPremium,
    required this.onInterested,
    required this.onPass,
  });

  final MatchModel match;
  final bool hasPremium;
  final Future<void> Function() onInterested;
  final Future<void> Function() onPass;

  @override
  State<_SuggestionActionSection> createState() =>
      _SuggestionActionSectionState();
}

class _SuggestionActionSectionState extends State<_SuggestionActionSection> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    if (match.status == MatchStatus.mutual ||
        match.status == MatchStatus.active) {
      return DuoGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "It's mutual",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.hasPremium
                  ? 'You both want to connect. Premium includes up to 3 new conversation activations each week.'
                  : 'You both want to connect. Basic includes 1 new conversation activation each week.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            DuoButton(
              label: widget.hasPremium
                  ? 'Start Conversation'
                  : 'View Conversation Options',
              onPressed: () => context.push(
                widget.hasPremium
                    ? AppRoutePaths.chat
                    : AppRoutePaths.subscription,
              ),
            ),
          ],
        ),
      );
    }

    if (match.status == MatchStatus.interested) {
      return DuoGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interest sent',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "We'll let you know if this becomes mutual.",
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: DuoButton(
            label: 'Pass',
            variant: DuoButtonVariant.secondary,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : () => _submit(widget.onPass),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: DuoButton(
            label: "I'm Interested",
            isLoading: _isSubmitting,
            onPressed: _isSubmitting
                ? null
                : () => _submit(widget.onInterested),
          ),
        ),
      ],
    );
  }

  Future<void> _submit(Future<void> Function() action) async {
    setState(() => _isSubmitting = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _ReportScoreRow extends StatelessWidget {
  const _ReportScoreRow({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '$score%',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.accent),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (score / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.cardStroke,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ),
      ],
    );
  }
}

class _EmptyMatchView extends StatelessWidget {
  const _EmptyMatchView({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return DuoPrimaryScaffold(
      currentIndex: 0,
      title: 'Your Weekly Match',
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'Your next meaningful introduction is still being prepared. Check back soon after the weekly generation cycle completes.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            DuoGlassCard(
              child: Column(
                children: [
                  const Icon(
                    Icons.favorite_outline_rounded,
                    size: 60,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'No Match Yet',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchLoadingView extends StatelessWidget {
  const _MatchLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _MatchErrorView extends StatelessWidget {
  const _MatchErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: DuoGlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'We could not load your weekly match.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Pull to refresh or try again to request your latest compatibility result.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                DuoButton(label: 'Try Again', onPressed: onRetry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
