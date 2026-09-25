import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_route_paths.dart';
import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../controllers/questionnaire_one_controller.dart';
import '../widgets/onboarding_choice_chip.dart';
import '../widgets/onboarding_progress_card.dart';

class QuestionnaireOneScreen extends ConsumerWidget {
  const QuestionnaireOneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(questionnaireOneControllerProvider);

    return state.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'We could not load Questionnaire One.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (questionnaire) {
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
                    const OnboardingProgressCard(
                      step: 1,
                      totalSteps: 1,
                      completionPercent: 100,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Questionnaire One',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Interests',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: AppColors.accent),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Choose the things that naturally pull you in. We use them to improve compatibility scoring and make introductions feel more intentional.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    DuoGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select all that fit',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: QuestionnaireOneController
                                .availableInterests
                                .map(
                                  (interest) => OnboardingChoiceChip(
                                    label: interest,
                                    selected: questionnaire.selectedInterests
                                        .contains(interest),
                                    onTap: () => ref
                                        .read(
                                          questionnaireOneControllerProvider
                                              .notifier,
                                        )
                                        .toggleInterest(interest),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            '${questionnaire.selectedInterests.length} selected',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    DuoButton(
                      label: 'Continue',
                      isLoading: questionnaire.isSaving,
                      onPressed: questionnaire.selectedInterests.isEmpty
                          ? null
                          : () async {
                              await ref
                                  .read(
                                    questionnaireOneControllerProvider.notifier,
                                  )
                                  .saveSelections();

                              final nextState = ref.read(
                                questionnaireOneControllerProvider,
                              );
                              if (context.mounted && !nextState.hasError) {
                                context.go(AppRoutePaths.questionnaireTwo);
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
