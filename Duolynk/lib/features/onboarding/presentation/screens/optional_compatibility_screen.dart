import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/compatibility_question_schema.dart';
import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../controllers/optional_compatibility_controller.dart';
import '../widgets/onboarding_choice_chip.dart';
import '../widgets/onboarding_progress_card.dart';

class OptionalCompatibilityScreen extends ConsumerWidget {
  const OptionalCompatibilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(optionalCompatibilityControllerProvider);

    return state.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Improve your matches')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'We could not load these questions.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (questionnaire) {
        final total = CompatibilityQuestionSchema.optionalQuestions.length;
        final completionPercent = total == 0
            ? 0
            : ((questionnaire.completedCount / total) * 100).round();
        final controller = ref.read(
          optionalCompatibilityControllerProvider.notifier,
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Improve your matches')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            children: [
              OnboardingProgressCard(
                step: questionnaire.completedCount.clamp(0, total),
                totalSteps: total,
                completionPercent: completionPercent,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Improve your matches',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Answer a few optional questions to help Duolynk understand your compatibility profile in more detail.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              _QuestionCard(
                title: 'How do you most naturally show affection?',
                subtitle: 'Select all that feel like you.',
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: OptionalCompatibilityController.affectionOptions
                      .map((option) {
                        final selected =
                            (questionnaire.answers['affectionStyles']
                                        as List<dynamic>? ??
                                    const [])
                                .contains(option);
                        return OnboardingChoiceChip(
                          label: option,
                          selected: selected,
                          onTap: () => controller.toggleAffectionStyle(option),
                        );
                      })
                      .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SingleSelectQuestion(
                title: 'Which best describes your approach to money?',
                answerKey: 'financialAttitude',
                selectedValue:
                    questionnaire.answers['financialAttitude'] as String?,
                options:
                    OptionalCompatibilityController.financialAttitudeOptions,
                onSelect: controller.selectAnswer,
              ),
              const SizedBox(height: AppSpacing.lg),
              _SingleSelectQuestion(
                title: 'How do pets fit into your life?',
                answerKey: 'pets',
                selectedValue: questionnaire.answers['pets'] as String?,
                options: OptionalCompatibilityController.petOptions,
                onSelect: controller.selectAnswer,
              ),
              const SizedBox(height: AppSpacing.lg),
              _SingleSelectQuestion(
                title:
                    'Would you consider relocating for the right relationship?',
                answerKey: 'relocationOpenness',
                selectedValue:
                    questionnaire.answers['relocationOpenness'] as String?,
                options: OptionalCompatibilityController.relocationOptions,
                onSelect: controller.selectAnswer,
              ),
              const SizedBox(height: AppSpacing.lg),
              _SingleSelectQuestion(
                title:
                    'How important is sharing a similar cultural background with a partner?',
                answerKey: 'culturalBackgroundImportance',
                selectedValue:
                    questionnaire.answers['culturalBackgroundImportance']
                        as String?,
                options: OptionalCompatibilityController.importanceOptions,
                onSelect: controller.selectAnswer,
              ),
              const SizedBox(height: AppSpacing.lg),
              _SingleSelectQuestion(
                title:
                    'How important is having similar political views in a relationship?',
                subtitle:
                    'Duolynk does not ask for or infer political affiliation here.',
                answerKey: 'politicalViewsImportance',
                selectedValue:
                    questionnaire.answers['politicalViewsImportance']
                        as String?,
                options: OptionalCompatibilityController.importanceOptions,
                onSelect: controller.selectAnswer,
              ),
              const SizedBox(height: AppSpacing.xl),
              DuoButton(
                label: 'Save Optional Answers',
                isLoading: questionnaire.isSaving,
                onPressed: () async {
                  await controller.save();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Your compatibility profile is now more detailed.',
                        ),
                      ),
                    );
                    context.pop();
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Skip for now'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SingleSelectQuestion extends StatelessWidget {
  const _SingleSelectQuestion({
    required this.title,
    required this.answerKey,
    required this.selectedValue,
    required this.options,
    required this.onSelect,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String answerKey;
  final String? selectedValue;
  final List<String> options;
  final void Function({required String key, required String value}) onSelect;

  @override
  Widget build(BuildContext context) {
    return _QuestionCard(
      title: title,
      subtitle: subtitle,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: options
            .map(
              (option) => OnboardingChoiceChip(
                label: option,
                selected: selectedValue == option,
                onTap: () => onSelect(key: answerKey, value: option),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DuoGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
