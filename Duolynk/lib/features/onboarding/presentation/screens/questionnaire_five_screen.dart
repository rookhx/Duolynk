import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../controllers/questionnaire_five_controller.dart';
import '../widgets/onboarding_choice_chip.dart';
import '../widgets/onboarding_progress_card.dart';

class QuestionnaireFiveScreen extends ConsumerWidget {
  const QuestionnaireFiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(questionnaireFiveControllerProvider);

    return state.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'We could not load Questionnaire Five.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (questionnaire) {
        final completionPercent = ((questionnaire.completedCount / 4) * 100)
            .round();

        return Scaffold(
          body: Stack(
            children: [
              const _QuestionnaireBackground(),
              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  children: [
                    OnboardingProgressCard(
                      step: questionnaire.completedCount.clamp(1, 4),
                      totalSteps: 4,
                      completionPercent: completionPercent,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Questionnaire Five',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Preferences & Deal Breakers',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: AppColors.accent),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Define the practical boundaries and expectations that matter most so Duolynk can filter for stronger long-term compatibility.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _QuestionCard(
                      title: 'Age Range',
                      subtitle: 'What age range feels most aligned for you?',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: QuestionnaireFiveController.ageRanges
                            .map(
                              (option) => OnboardingChoiceChip(
                                label: option,
                                selected: questionnaire.ageRange == option,
                                onTap: () => ref
                                    .read(
                                      questionnaireFiveControllerProvider
                                          .notifier,
                                    )
                                    .selectAgeRange(option),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _QuestionCard(
                      title: 'Distance Preference',
                      subtitle:
                          'How wide should Duolynk search for a meaningful match?',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: QuestionnaireFiveController
                            .distancePreferences
                            .map(
                              (option) => OnboardingChoiceChip(
                                label: option,
                                selected:
                                    questionnaire.distancePreference == option,
                                onTap: () => ref
                                    .read(
                                      questionnaireFiveControllerProvider
                                          .notifier,
                                    )
                                    .selectDistancePreference(option),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _QuestionCard(
                      title: 'Deal Breakers',
                      subtitle:
                          'A deal breaker means Duolynk should not introduce you to someone who conflicts with that requirement.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: QuestionnaireFiveController
                                .dealBreakerOptions
                                .map(
                                  (option) => OnboardingChoiceChip(
                                    label: option,
                                    selected: questionnaire.dealBreakers
                                        .contains(option),
                                    onTap: () => ref
                                        .read(
                                          questionnaireFiveControllerProvider
                                              .notifier,
                                        )
                                        .toggleDealBreaker(option),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '${questionnaire.dealBreakers.length} selected',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _QuestionCard(
                      title: 'Relationship Expectations',
                      subtitle:
                          'Choose the expectation that matters most at the start of a relationship.',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: QuestionnaireFiveController
                            .relationshipExpectationOptions
                            .map(
                              (option) => OnboardingChoiceChip(
                                label: option,
                                selected:
                                    questionnaire.relationshipExpectations ==
                                    option,
                                onTap: () => ref
                                    .read(
                                      questionnaireFiveControllerProvider
                                          .notifier,
                                    )
                                    .selectRelationshipExpectation(option),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    DuoButton(
                      label: 'Save Preferences',
                      isLoading: questionnaire.isSaving,
                      onPressed: !questionnaire.isComplete
                          ? null
                          : () async {
                              await ref
                                  .read(
                                    questionnaireFiveControllerProvider
                                        .notifier,
                                  )
                                  .saveResults();

                              final nextState = ref.read(
                                questionnaireFiveControllerProvider,
                              );
                              if (context.mounted && !nextState.hasError) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Preferences and deal breakers saved to Firestore.',
                                    ),
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DuoGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _QuestionnaireBackground extends StatelessWidget {
  const _QuestionnaireBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.background),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -50,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x30FF3E9E),
                    Color(0x1AB26BFF),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -110,
            left: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x28B26BFF),
                    Color(0x18FF3E9E),
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
