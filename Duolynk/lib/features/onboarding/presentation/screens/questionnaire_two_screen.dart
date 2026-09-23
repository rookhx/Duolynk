import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../controllers/questionnaire_two_controller.dart';
import '../widgets/onboarding_choice_chip.dart';
import '../widgets/onboarding_progress_card.dart';

class QuestionnaireTwoScreen extends ConsumerWidget {
  const QuestionnaireTwoScreen({super.key});

  static const _labels = {
    'smoking': 'Smoking',
    'drinking': 'Drinking',
    'religionImportance': 'Religion Importance',
    'exerciseFrequency': 'Exercise Frequency',
    'dietPreference': 'Diet Preference',
    'sleepingSchedule': 'Sleeping Schedule',
    'socialLifestyle': 'Social Lifestyle',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(questionnaireTwoControllerProvider);

    return state.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'We could not load Questionnaire Two.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (questionnaire) {
        final completionPercent =
            ((questionnaire.answers.length /
                        QuestionnaireTwoController.questions.length) *
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
                        QuestionnaireTwoController.questions.length,
                      ),
                      totalSteps: QuestionnaireTwoController.questions.length,
                      completionPercent: completionPercent,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Questionnaire Two',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Lifestyle',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: AppColors.accent),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Help Duolynk understand the rhythms of your daily life. These answers shape compatibility beyond attraction.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ...QuestionnaireTwoController.questions.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: DuoGlassCard(
                          child: _QuestionCard(
                            title: _labels[entry.key] ?? entry.key,
                            selectedValue: questionnaire.answers[entry.key],
                            options: entry.value,
                            onSelect: (answer) => ref
                                .read(
                                  questionnaireTwoControllerProvider.notifier,
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
                      label: 'Save Lifestyle Results',
                      isLoading: questionnaire.isSaving,
                      onPressed: !questionnaire.isComplete
                          ? null
                          : () async {
                              await ref
                                  .read(
                                    questionnaireTwoControllerProvider.notifier,
                                  )
                                  .saveResults();

                              final nextState = ref.read(
                                questionnaireTwoControllerProvider,
                              );
                              if (context.mounted && !nextState.hasError) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Lifestyle questionnaire saved to Firestore.',
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
