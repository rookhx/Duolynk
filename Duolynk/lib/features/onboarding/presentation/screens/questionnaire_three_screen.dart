import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_route_paths.dart';
import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../controllers/questionnaire_three_controller.dart';
import '../widgets/onboarding_choice_chip.dart';
import '../widgets/onboarding_progress_card.dart';

class QuestionnaireThreeScreen extends ConsumerWidget {
  const QuestionnaireThreeScreen({super.key});

  static const _labels = {
    'introvertExtrovert': 'Introvert / Extrovert',
    'planningVsSpontaneous': 'Planning vs Spontaneous',
    'riskTaking': 'Risk Taking',
    'communicationStyle': 'Communication Style',
    'communicationFrequency': 'Communication Rhythm',
    'conflictResolution': 'Conflict Resolution',
    'humorStyle': 'Humor Style',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(questionnaireThreeControllerProvider);

    return state.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'We could not load Questionnaire Three.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (questionnaire) {
        final completionPercent =
            ((questionnaire.answers.length /
                        QuestionnaireThreeController.questions.length) *
                    100)
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
                      step: questionnaire.answers.length.clamp(
                        1,
                        QuestionnaireThreeController.questions.length,
                      ),
                      totalSteps: QuestionnaireThreeController.questions.length,
                      completionPercent: completionPercent,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Questionnaire Three',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Personality',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: AppColors.accent),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Tell Duolynk how you naturally move through conversation, decisions, energy, and connection. This helps us match beyond surface-level preferences.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ...QuestionnaireThreeController.questions.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: DuoGlassCard(
                          child: _QuestionCard(
                            title: _labels[entry.key] ?? entry.key,
                            selectedValue: questionnaire.answers[entry.key],
                            options: entry.value,
                            onSelect: (answer) => ref
                                .read(
                                  questionnaireThreeControllerProvider.notifier,
                                )
                                .selectAnswer(
                                  questionKey: entry.key,
                                  answer: answer,
                                ),
                          ),
                        ),
                      ),
                    ),
                    DuoButton(
                      label: 'Continue',
                      isLoading: questionnaire.isSaving,
                      onPressed: !questionnaire.isComplete
                          ? null
                          : () async {
                              await ref
                                  .read(
                                    questionnaireThreeControllerProvider
                                        .notifier,
                                  )
                                  .saveResults();

                              final nextState = ref.read(
                                questionnaireThreeControllerProvider,
                              );
                              if (context.mounted && !nextState.hasError) {
                                context.go(AppRoutePaths.questionnaireFour);
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
    required this.options,
    required this.onSelect,
    this.selectedValue,
  });

  final String title;
  final List<String> options;
  final String? selectedValue;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: options
              .map(
                (option) => OnboardingChoiceChip(
                  label: option,
                  selected: selectedValue == option,
                  onTap: () => onSelect(option),
                ),
              )
              .toList(),
        ),
      ],
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
