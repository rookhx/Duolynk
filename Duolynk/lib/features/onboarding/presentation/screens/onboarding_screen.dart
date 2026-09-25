import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_route_paths.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../core/config/profile_prompt_library.dart';
import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../core/widgets/fields/duo_text_field.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../models/profile_prompt_answer.dart';
import '../../domain/onboarding_state.dart';
import '../controllers/onboarding_controller.dart';
import '../widgets/onboarding_choice_chip.dart';
import '../widgets/onboarding_progress_card.dart';
import '../widgets/photo_picker_grid.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  // Mirrors the bio rule in OnboardingState.canContinueCurrentStep.
  static const _minBioLength = 20;

  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();

  bool _controllersSeeded = false;

  static const _genders = ['Woman', 'Man', 'Non-binary', 'Prefer not to say'];
  static const _interests = ['Women', 'Men', 'Non-binary people', 'Everyone'];

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingControllerProvider);

    return onboardingState.when(
      loading: () => const _OnboardingLoading(),
      error: (error, stackTrace) => _OnboardingError(error: error),
      data: (state) {
        _seedControllers(state);

        return Scaffold(
          body: Stack(
            children: [
              const _OnboardingBackground(),
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
                      step: state.currentStep,
                      totalSteps: state.totalSteps,
                      completionPercent: state.completionPercent,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      _titleForStep(state.currentStep),
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _subtitleForStep(state.currentStep),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: DuoGlassCard(
                        key: ValueKey<int>(state.currentStep),
                        child: _buildStep(context, state),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        if (state.currentStep > 1)
                          Expanded(
                            child: DuoButton(
                              label: 'Back',
                              variant: DuoButtonVariant.secondary,
                              onPressed: () => ref
                                  .read(onboardingControllerProvider.notifier)
                                  .goBackStep(),
                            ),
                          ),
                        if (state.currentStep > 1)
                          const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: DuoButton(
                            label: state.currentStep == state.totalSteps
                                ? 'Complete Profile'
                                : 'Continue',
                            onPressed: () =>
                                _handlePrimaryAction(state.currentStep),
                            isLoading: state.isSubmitting,
                          ),
                        ),
                      ],
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

  Widget _buildStep(BuildContext context, OnboardingState state) {
    switch (state.currentStep) {
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DuoTextField(
              controller: _nameController,
              label: 'Name',
              hintText: 'How should your match know you?',
              prefixIcon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              onFieldSubmitted: (value) => ref
                  .read(onboardingControllerProvider.notifier)
                  .updateName(value),
            ),
            const SizedBox(height: AppSpacing.md),
            _DateOfBirthPicker(
              dateOfBirth: state.dateOfBirth,
              derivedAge: state.derivedAge,
              onChanged: (date) => ref
                  .read(onboardingControllerProvider.notifier)
                  .updateDateOfBirth(date),
            ),
            if (state.dateOfBirth != null && !state.isAdult) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Duolynk is only available to people aged 18 or older.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.accent),
              ),
            ],
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gender', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _genders
                  .map(
                    (gender) => OnboardingChoiceChip(
                      label: gender,
                      selected: state.gender == gender,
                      onTap: () => ref
                          .read(onboardingControllerProvider.notifier)
                          .updateGender(gender),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Interested In',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _interests
                  .map(
                    (value) => OnboardingChoiceChip(
                      label: value,
                      selected: state.interestedIn.contains(value),
                      onTap: () => ref
                          .read(onboardingControllerProvider.notifier)
                          .toggleInterestedIn(value),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DuoTextField(
              controller: _countryController,
              label: 'Country',
              hintText: 'Where are you based?',
              prefixIcon: Icons.public_rounded,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.md),
            DuoTextField(
              controller: _cityController,
              label: 'City',
              hintText: 'Your current city',
              prefixIcon: Icons.location_on_outlined,
              textCapitalization: TextCapitalization.words,
            ),
          ],
        );
      case 4:
        return PhotoPickerGrid(
          remotePhotoUrls: state.remotePhotoUrls,
          localPhotos: state.localPhotoBytes,
          onAddPhotos: () =>
              ref.read(onboardingControllerProvider.notifier).pickPhotos(),
          onRemoveRemote: (index) => ref
              .read(onboardingControllerProvider.notifier)
              .removeRemotePhotoAt(index),
          onRemoveLocal: (index) => ref
              .read(onboardingControllerProvider.notifier)
              .removeLocalPhotoAt(index),
        );
      case 5:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DuoTextField(
              controller: _bioController,
              label: 'Bio',
              hintText:
                  'Share a thoughtful snapshot of your personality, values, and what makes a great connection for you.',
              prefixIcon: Icons.edit_note_rounded,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.sm),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _bioController,
              builder: (context, value, _) {
                final length = value.text.trim().length;
                return Text(
                  length >= _minBioLength
                      ? '$length characters. Looking good!'
                      : 'Aim for at least $_minBioLength characters to give your future match real signal. ($length/$_minBioLength)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                );
              },
            ),
          ],
        );
      case 6:
        return _PromptStep(state: state);
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReviewLine(label: 'Name', value: state.displayName),
            _ReviewLine(label: 'Age', value: '${state.derivedAge ?? ''}'),
            _ReviewLine(label: 'Gender', value: state.gender),
            _ReviewLine(
              label: 'Interested In',
              value: state.interestedIn.join(', '),
            ),
            _ReviewLine(label: 'Country', value: state.country),
            _ReviewLine(label: 'City', value: state.city),
            _ReviewLine(
              label: 'Photos',
              value:
                  '${state.remotePhotoUrls.length + state.localPhotoBytes.length} added',
            ),
            _ReviewLine(label: 'Bio', value: state.bio),
            _ReviewLine(
              label: 'Prompts',
              value: '${state.profilePrompts.length} answered',
            ),
          ],
        );
    }
  }

  Future<void> _handlePrimaryAction(int currentStep) async {
    _syncTextControllers();
    final controller = ref.read(onboardingControllerProvider.notifier);

    if (currentStep == 7) {
      final success = await controller.completeOnboarding();
      if (!mounted) {
        return;
      }
      if (success) {
        // The session caches the user doc read at sign-in, which still says
        // the profile is incomplete; the router would bounce us back here.
        ref.invalidate(authSessionProvider);
        await ref.read(authSessionProvider.future);
        if (!mounted) {
          return;
        }
        context.go(AppRoutePaths.matching);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('We could not finish setting up your profile.'),
          ),
        );
      }
      return;
    }

    final state = ref.read(onboardingControllerProvider).requireValue;
    if (!state.canContinueCurrentStep) {
      _showMessage(_incompleteStepMessage(currentStep));
      return;
    }

    try {
      await controller.continueStep();
    } catch (error) {
      debugPrint('Onboarding draft save failed: $error');
      _showMessage('We could not save your progress. Please try again.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _incompleteStepMessage(int step) {
    switch (step) {
      case 1:
        return 'Add your name and a date of birth showing you are 18 or older.';
      case 2:
        return 'Choose your gender and who you are interested in.';
      case 3:
        return 'Add your country and city.';
      case 4:
        return 'Add at least one photo to continue.';
      case 5:
        return 'Your bio needs at least $_minBioLength characters.';
      case 6:
        return 'Pick ${ProfilePromptLibrary.requiredPromptCount} different prompts and answer each one.';
      default:
        return 'Please complete this step to continue.';
    }
  }

  void _syncTextControllers() {
    final controller = ref.read(onboardingControllerProvider.notifier);
    controller.updateName(_nameController.text);
    controller.updateCountry(_countryController.text);
    controller.updateCity(_cityController.text);
    controller.updateBio(_bioController.text);
  }

  void _seedControllers(OnboardingState state) {
    if (_controllersSeeded) {
      return;
    }
    _nameController.text = state.displayName;
    _countryController.text = state.country;
    _cityController.text = state.city;
    _bioController.text = state.bio;
    _controllersSeeded = true;
  }

  String _titleForStep(int step) {
    switch (step) {
      case 1:
        return 'Let’s start with the essentials';
      case 2:
        return 'Define your connection preferences';
      case 3:
        return 'Place you in the right city';
      case 4:
        return 'Curate your first impression';
      case 5:
        return 'Write a bio that feels like you';
      case 6:
        return 'Add a few conversation starters';
      default:
        return 'Review your Duolynk profile';
    }
  }

  String _subtitleForStep(int step) {
    switch (step) {
      case 1:
        return 'Your date of birth stays private. Matches only see your age.';
      case 2:
        return 'These choices help us introduce you to people with aligned intent.';
      case 3:
        return 'Compatibility is stronger when the practical details line up too.';
      case 4:
        return 'Choose photos that feel natural, confident, and unmistakably you.';
      case 5:
        return 'A strong bio turns profile data into real personality.';
      case 6:
        return 'Choose three prompts that help your match understand who you are.';
      default:
        return 'Take one last look before we start delivering more thoughtful matches.';
    }
  }
}

class _PromptStep extends ConsumerWidget {
  const _PromptStep({required this.state});

  final OnboardingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prompts = [...state.profilePrompts];
    while (prompts.length < ProfilePromptLibrary.requiredPromptCount) {
      prompts.add(const ProfilePromptAnswer(promptId: '', answer: ''));
    }
    final visiblePrompts = prompts
        .take(ProfilePromptLibrary.requiredPromptCount)
        .toList();
    // Prompts not already chosen in another slot, plus this slot's choice.
    List<ProfilePromptDefinition> availablePrompts(int index) => ProfilePromptLibrary
        .prompts
        .where(
          (prompt) =>
              prompt.id == visiblePrompts[index].promptId ||
              !visiblePrompts.any((answer) => answer.promptId == prompt.id),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < visiblePrompts.length; index++) ...[
          DropdownButtonFormField<String>(
            initialValue: visiblePrompts[index].promptId.isEmpty
                ? null
                : visiblePrompts[index].promptId,
            decoration: InputDecoration(labelText: 'Prompt ${index + 1}'),
            // Prompt texts are long: fill the width, wrap in the menu, and
            // ellipsize the selected value instead of overflowing.
            isExpanded: true,
            itemHeight: null,
            selectedItemBuilder: (context) => availablePrompts(index)
                .map(
                  (prompt) => Text(
                    prompt.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
                .toList(),
            items: availablePrompts(index)
                .map(
                  (prompt) => DropdownMenuItem<String>(
                    value: prompt.id,
                    child: Text(
                      prompt.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => ref
                .read(onboardingControllerProvider.notifier)
                .updatePromptAt(index, promptId: value ?? ''),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: visiblePrompts[index].answer,
            maxLength: ProfilePromptLibrary.answerCharacterLimit,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Your answer'),
            onChanged: (value) => ref
                .read(onboardingControllerProvider.notifier)
                .updatePromptAt(index, answer: value),
          ),
          if (index != visiblePrompts.length - 1)
            const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _DateOfBirthPicker extends StatelessWidget {
  const _DateOfBirthPicker({
    required this.dateOfBirth,
    required this.derivedAge,
    required this.onChanged,
  });

  final DateTime? dateOfBirth;
  final int? derivedAge;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = dateOfBirth == null
        ? 'Select date of birth'
        : '${dateOfBirth!.month}/${dateOfBirth!.day}/${dateOfBirth!.year}';
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final now = DateTime.now();
        final selected = await showDatePicker(
          context: context,
          initialDate:
              dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
          firstDate: DateTime(now.year - 100),
          lastDate: now,
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date of birth',
          prefixIcon: Icon(Icons.cake_outlined),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            if (derivedAge != null)
              Text(
                '$derivedAge',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _OnboardingBackground extends StatelessWidget {
  const _OnboardingBackground();

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
                    Color(0x32FF3E9E),
                    Color(0x1CB26BFF),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
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

class _OnboardingLoading extends StatelessWidget {
  const _OnboardingLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _OnboardingError extends StatelessWidget {
  const _OnboardingError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'We could not load your onboarding flow.\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
