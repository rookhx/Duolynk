import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../profile/data/profile_repository.dart';
import '../../../../models/profile_prompt_answer.dart';
import '../../../../services/profile/dating_profile_service.dart';
import '../../../../services/safety/age_policy_service.dart';
import '../../data/onboarding_repository.dart';
import '../../domain/onboarding_state.dart';

final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

class OnboardingController extends AsyncNotifier<OnboardingState> {
  late final OnboardingRepository _repository;
  late final ProfileRepository _profileRepository;
  late final ImagePicker _imagePicker;

  @override
  Future<OnboardingState> build() async {
    _repository = ref.read(onboardingRepositoryProvider);
    _profileRepository = ref.read(profileRepositoryProvider);
    _imagePicker = ref.read(imagePickerProvider);

    final user = await _repository.fetchCurrentProfile();
    final draft = await _repository.fetchDraft();
    final initial = OnboardingState.initial(user: user);

    if (draft == null) {
      return initial;
    }

    return initial.copyWith(
      currentStep: draft.completedSteps.clamp(1, initial.totalSteps),
      displayName:
          draft.answers['displayName'] as String? ?? initial.displayName,
      age: draft.answers['age'] as int? ?? initial.age,
      dateOfBirth:
          _readDraftDate(draft.answers['dateOfBirth']) ?? initial.dateOfBirth,
      gender: draft.answers['gender'] as String? ?? initial.gender,
      interestedIn:
          (draft.answers['interestedIn'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(),
      country: draft.answers['country'] as String? ?? initial.country,
      city: draft.answers['city'] as String? ?? initial.city,
      bio: draft.answers['bio'] as String? ?? initial.bio,
      profilePrompts:
          (draft.answers['profilePrompts'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(ProfilePromptAnswer.fromMap)
              .toList()
              .isNotEmpty
          ? (draft.answers['profilePrompts'] as List<dynamic>)
                .whereType<Map>()
                .map(ProfilePromptAnswer.fromMap)
                .toList()
          : initial.profilePrompts,
      remotePhotoUrls:
          (draft.answers['photoUrls'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList()
              .isNotEmpty
          ? (draft.answers['photoUrls'] as List<dynamic>)
                .whereType<String>()
                .toList()
          : initial.remotePhotoUrls,
    );
  }

  void updateName(String value) =>
      _setState(state.requireValue.copyWith(displayName: value));

  void updateAge(String value) {
    final parsed = int.tryParse(value);
    _setState(
      state.requireValue.copyWith(age: parsed, clearAge: parsed == null),
    );
  }

  void updateDateOfBirth(DateTime value) {
    _setState(
      state.requireValue.copyWith(
        dateOfBirth: value,
        age: const AgePolicyService().ageOnDate(value, DateTime.now()),
      ),
    );
  }

  void updateGender(String value) =>
      _setState(state.requireValue.copyWith(gender: value));

  void toggleInterestedIn(String value) {
    final current = [...state.requireValue.interestedIn];
    if (current.contains(value)) {
      current.remove(value);
    } else {
      current.add(value);
    }
    _setState(state.requireValue.copyWith(interestedIn: current));
  }

  void updateCountry(String value) =>
      _setState(state.requireValue.copyWith(country: value));

  void updateCity(String value) =>
      _setState(state.requireValue.copyWith(city: value));

  void updateBio(String value) =>
      _setState(state.requireValue.copyWith(bio: value));

  void updatePromptAt(int index, {String? promptId, String? answer}) {
    final prompts = [...state.requireValue.profilePrompts];
    while (prompts.length <= index) {
      prompts.add(const ProfilePromptAnswer(promptId: '', answer: ''));
    }
    final current = prompts[index];
    prompts[index] = ProfilePromptAnswer(
      promptId: promptId ?? current.promptId,
      answer: answer ?? current.answer,
    );
    _setState(state.requireValue.copyWith(profilePrompts: prompts));
  }

  Future<void> pickPhotos() async {
    final files = await _imagePicker.pickMultiImage(
      imageQuality: 88,
      maxWidth: 1440,
    );
    if (files.isEmpty) {
      return;
    }

    final bytes = await Future.wait(files.map((file) => file.readAsBytes()));
    final availableSlots =
        DatingProfileService.maxPhotoCount -
        state.requireValue.remotePhotoUrls.length -
        state.requireValue.localPhotoBytes.length;
    final merged = [
      ...state.requireValue.localPhotoBytes,
      ...bytes.take(availableSlots),
    ];
    _setState(state.requireValue.copyWith(localPhotoBytes: merged));
  }

  void removeRemotePhotoAt(int index) {
    final photos = [...state.requireValue.remotePhotoUrls]..removeAt(index);
    _setState(state.requireValue.copyWith(remotePhotoUrls: photos));
  }

  void removeLocalPhotoAt(int index) {
    final photos = [...state.requireValue.localPhotoBytes]..removeAt(index);
    _setState(state.requireValue.copyWith(localPhotoBytes: photos));
  }

  Future<void> continueStep() async {
    final current = state.requireValue;
    if (!current.canContinueCurrentStep) {
      return;
    }
    await saveDraft();
    if (current.currentStep < current.totalSteps) {
      _setState(current.copyWith(currentStep: current.currentStep + 1));
    }
  }

  void goBackStep() {
    final current = state.requireValue;
    if (current.currentStep == 1) {
      return;
    }
    _setState(current.copyWith(currentStep: current.currentStep - 1));
  }

  Future<void> saveDraft() async {
    final current = state.requireValue;
    await _repository.persistDraft(
      answers: _draftAnswers(current),
      completedSteps: current.currentStep,
      totalSteps: current.totalSteps,
      isComplete: current.completionRatio >= 1,
    );
    _setState(current.copyWith(isDraftSaved: true));
  }

  Future<bool> completeOnboarding() async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isSubmitting: true));

    try {
      if (!current.isAdult) {
        throw StateError(
          'Duolynk is only available to people aged 18 or older.',
        );
      }
      final baseUser = await _repository.fetchCurrentProfile();
      if (baseUser == null) {
        throw StateError('A signed-in user profile is required.');
      }

      var uploadedUrls = current.remotePhotoUrls;
      if (current.localPhotoBytes.isNotEmpty) {
        final newUrls = await _profileRepository.uploadProfilePhotos(
          userId: baseUser.id,
          images: current.localPhotoBytes,
        );
        uploadedUrls = [...uploadedUrls, ...newUrls];
      }

      final user = current.toAppUser(baseUser, photoUrls: uploadedUrls);
      await _repository.saveProfile(user);
      await _repository.persistDraft(
        answers: _draftAnswers(
          current.copyWith(
            remotePhotoUrls: uploadedUrls,
            localPhotoBytes: const [],
          ),
        ),
        completedSteps: current.totalSteps,
        totalSteps: current.totalSteps,
        isComplete: true,
      );

      state = AsyncData(
        current.copyWith(
          remotePhotoUrls: uploadedUrls,
          localPhotoBytes: const [],
          isSubmitting: false,
          isDraftSaved: true,
        ),
      );
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  void _setState(OnboardingState next) {
    state = AsyncData(next.copyWith(isDraftSaved: false));
  }

  Map<String, dynamic> _draftAnswers(OnboardingState state) {
    return {
      'displayName': state.displayName.trim(),
      'age': state.age,
      'dateOfBirth': state.dateOfBirth?.toIso8601String(),
      'gender': state.gender,
      'interestedIn': state.interestedIn,
      'country': state.country.trim(),
      'city': state.city.trim(),
      'bio': state.bio.trim(),
      'profilePrompts': const DatingProfileService()
          .normalizePromptAnswers(state.profilePrompts)
          .map((prompt) => prompt.toMap())
          .toList(),
      'photoUrls': state.remotePhotoUrls,
    };
  }

  DateTime? _readDraftDate(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
