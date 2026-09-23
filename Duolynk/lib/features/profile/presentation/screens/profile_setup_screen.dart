import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/profile_prompt_library.dart';
import '../../../../core/routing/app_route_paths.dart';
import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../core/widgets/fields/duo_text_field.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../models/app_user.dart';
import '../../../../models/profile_prompt_answer.dart';
import '../../../../services/analytics/analytics_event_service.dart';
import '../../../../services/profile/dating_profile_service.dart';
import '../../../onboarding/presentation/widgets/onboarding_choice_chip.dart';
import '../../../onboarding/presentation/widgets/photo_picker_grid.dart';
import '../../data/profile_repository.dart';
import '../../presentation/controllers/profile_controller.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
  final _picker = ImagePicker();

  String _gender = '';
  List<String> _interestedIn = [];
  List<String> _remotePhotos = [];
  List<Uint8List> _localPhotos = [];
  List<ProfilePromptAnswer> _profilePrompts = [];
  bool _seeded = false;

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
    final profileState = ref.watch(profileControllerProvider);

    return profileState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        body: Center(child: Text('Could not load profile.\n$error')),
      ),
      data: (state) {
        final user = state.user;
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('No signed-in profile found.')),
          );
        }

        _seed(user);

        return Scaffold(
          appBar: AppBar(title: const Text('Edit Profile')),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Completion',
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
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              DuoGlassCard(
                child: Column(
                  children: [
                    DuoTextField(
                      controller: _nameController,
                      label: 'Name',
                      prefixIcon: Icons.person_outline_rounded,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _AccountAgeNotice(user: user),
                    const SizedBox(height: AppSpacing.md),
                    _SectionLabel(text: 'Gender'),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: _genders
                          .map(
                            (value) => OnboardingChoiceChip(
                              label: value,
                              selected: _gender == value,
                              onTap: () => setState(() => _gender = value),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SectionLabel(text: 'Interested In'),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: _interests
                          .map(
                            (value) => OnboardingChoiceChip(
                              label: value,
                              selected: _interestedIn.contains(value),
                              onTap: () => setState(() {
                                if (_interestedIn.contains(value)) {
                                  _interestedIn.remove(value);
                                } else {
                                  _interestedIn.add(value);
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    DuoTextField(
                      controller: _countryController,
                      label: 'Country',
                      prefixIcon: Icons.public_rounded,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DuoTextField(
                      controller: _cityController,
                      label: 'City',
                      prefixIcon: Icons.location_on_outlined,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DuoTextField(
                      controller: _bioController,
                      label: 'Bio',
                      prefixIcon: Icons.edit_note_rounded,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: DatingProfileService.bioCharacterLimit,
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
                      'Photos',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PhotoPickerGrid(
                      remotePhotoUrls: _remotePhotos,
                      localPhotos: _localPhotos,
                      onAddPhotos: _pickPhotos,
                      onRemoveRemote: _removeRemotePhoto,
                      onRemoveLocal: _removeLocalPhoto,
                      onMoveRemoteUp: _moveRemotePhotoUp,
                      onMoveRemoteDown: _moveRemotePhotoDown,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              DuoGlassCard(
                child: _PromptEditor(
                  prompts: _promptRows,
                  onChanged: (index, answer) => setState(() {
                    while (_profilePrompts.length <= index) {
                      _profilePrompts.add(
                        const ProfilePromptAnswer(promptId: '', answer: ''),
                      );
                    }
                    _profilePrompts[index] = answer;
                  }),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              DuoButton(
                label: 'Preview My Profile',
                variant: DuoButtonVariant.secondary,
                onPressed: () async {
                  await const AnalyticsEventService().track(
                    'dating_profile_previewed',
                  );
                  if (context.mounted) {
                    context.push(AppRoutePaths.profilePreview);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              DuoButton(
                label: 'Save Changes',
                isLoading: state.isSaving,
                onPressed: () => _save(user),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickPhotos() async {
    final files = await _picker.pickMultiImage(
      imageQuality: 88,
      maxWidth: 1440,
    );
    if (files.isEmpty) {
      return;
    }
    final bytes = await Future.wait(files.map((file) => file.readAsBytes()));
    final availableSlots =
        DatingProfileService.maxPhotoCount -
        _remotePhotos.length -
        _localPhotos.length;
    setState(() {
      _localPhotos = [..._localPhotos, ...bytes.take(availableSlots)];
    });
  }

  Future<void> _save(AppUser user) async {
    final controller = ref.read(profileControllerProvider.notifier);

    var photoUrls = _remotePhotos;
    if (_localPhotos.isNotEmpty) {
      final uploaded = await ref
          .read(profileRepositoryProvider)
          .uploadProfilePhotos(userId: user.id, images: _localPhotos);
      photoUrls = [..._remotePhotos, ...uploaded];
    }
    if (!mounted) {
      return;
    }

    final profileService = const DatingProfileService();
    final normalizedPrompts = profileService.normalizePromptAnswers(
      _profilePrompts,
    );
    final shouldRequirePrompts =
        user.datingProfileVersion >= DatingProfileService.schemaVersion ||
        _profilePrompts.any(
          (prompt) =>
              prompt.promptId.trim().isNotEmpty ||
              prompt.answer.trim().isNotEmpty,
        );
    final promptError = profileService.promptValidationError(
      _profilePrompts,
      requireExactlyThree: shouldRequirePrompts,
    );
    if (promptError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(promptError)));
      return;
    }

    final normalizedBio = profileService.normalizeBio(_bioController.text);
    final normalizedPhotos = profileService.normalizePhotos(photoUrls);
    if (normalizedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one profile photo.')),
      );
      return;
    }

    final updatedUser = user.copyWith(
      displayName: _nameController.text.trim(),
      gender: _gender,
      interestedIn: _interestedIn,
      country: _countryController.text.trim(),
      city: _cityController.text.trim(),
      bio: normalizedBio,
      photoUrl: normalizedPhotos.first,
      photoUrls: normalizedPhotos,
      profilePrompts: normalizedPrompts,
      datingProfileVersion:
          profileService.hasValidPromptAnswers(normalizedPrompts)
          ? DatingProfileService.schemaVersion
          : user.datingProfileVersion,
    );

    await controller.saveProfile(updatedUser);
    if (normalizedPrompts.isNotEmpty) {
      await const AnalyticsEventService().track('profile_prompt_added');
    }
    await const AnalyticsEventService().track('dating_profile_updated');
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    setState(() {
      _remotePhotos = normalizedPhotos;
      _localPhotos = [];
      _profilePrompts = normalizedPrompts;
    });
  }

  void _seed(AppUser user) {
    if (_seeded) {
      return;
    }
    _nameController.text = user.displayName;
    _countryController.text = user.country ?? '';
    _cityController.text = user.city ?? '';
    _bioController.text = user.bio ?? '';
    _gender = user.gender == 'unspecified' ? '' : user.gender;
    _interestedIn = [...user.interestedIn];
    _remotePhotos = [...user.photoUrls];
    _profilePrompts = const DatingProfileService().normalizePromptAnswers(
      user.profilePrompts,
    );
    _seeded = true;
  }

  List<ProfilePromptAnswer> get _promptRows {
    final prompts = [..._profilePrompts];
    while (prompts.length < ProfilePromptLibrary.requiredPromptCount) {
      prompts.add(const ProfilePromptAnswer(promptId: '', answer: ''));
    }
    return prompts.take(ProfilePromptLibrary.requiredPromptCount).toList();
  }

  void _removeRemotePhoto(int index) {
    if (_remotePhotos.length + _localPhotos.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add another photo before removing this one.'),
        ),
      );
      return;
    }
    setState(() {
      _remotePhotos = [..._remotePhotos]..removeAt(index);
    });
  }

  void _removeLocalPhoto(int index) {
    if (_remotePhotos.length + _localPhotos.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add another photo before removing this one.'),
        ),
      );
      return;
    }
    setState(() {
      _localPhotos = [..._localPhotos]..removeAt(index);
    });
  }

  void _moveRemotePhotoUp(int index) {
    if (index <= 0) {
      return;
    }
    setState(() {
      final photos = [..._remotePhotos];
      final photo = photos.removeAt(index);
      photos.insert(index - 1, photo);
      _remotePhotos = photos;
    });
  }

  void _moveRemotePhotoDown(int index) {
    if (index >= _remotePhotos.length - 1) {
      return;
    }
    setState(() {
      final photos = [..._remotePhotos];
      final photo = photos.removeAt(index);
      photos.insert(index + 1, photo);
      _remotePhotos = photos;
    });
  }
}

class _PromptEditor extends StatelessWidget {
  const _PromptEditor({required this.prompts, required this.onChanged});

  final List<ProfilePromptAnswer> prompts;
  final void Function(int index, ProfilePromptAnswer answer) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profile prompts', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Choose 3 public prompts. These help matches get a real feel for you.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (var index = 0; index < prompts.length; index++) ...[
          DropdownButtonFormField<String>(
            initialValue: prompts[index].promptId.isEmpty
                ? null
                : prompts[index].promptId,
            decoration: InputDecoration(labelText: 'Prompt ${index + 1}'),
            items: ProfilePromptLibrary.prompts
                .where(
                  (prompt) =>
                      prompt.id == prompts[index].promptId ||
                      !prompts.any((answer) => answer.promptId == prompt.id),
                )
                .map(
                  (prompt) => DropdownMenuItem<String>(
                    value: prompt.id,
                    child: Text(prompt.text),
                  ),
                )
                .toList(),
            onChanged: (value) {
              onChanged(
                index,
                ProfilePromptAnswer(
                  promptId: value ?? '',
                  answer: prompts[index].answer,
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: prompts[index].answer,
            maxLength: ProfilePromptLibrary.answerCharacterLimit,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Your answer'),
            onChanged: (value) {
              onChanged(
                index,
                ProfilePromptAnswer(
                  promptId: prompts[index].promptId,
                  answer: value,
                ),
              );
            },
          ),
          if (index != prompts.length - 1)
            const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _AccountAgeNotice extends StatelessWidget {
  const _AccountAgeNotice({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardStroke),
      ),
      child: Row(
        children: [
          const Icon(Icons.cake_outlined, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              user.hasDateOfBirth
                  ? 'Age ${user.displayAge()} is calculated from your private date of birth.'
                  : 'Age ${user.displayAge()} is from your legacy profile. Date-of-birth updates will use a support/review flow later.',
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
