import 'dart:typed_data';

import '../../../models/app_user.dart';
import '../../../models/profile_prompt_answer.dart';
import '../../../services/safety/age_policy_service.dart';
import '../../../services/profile/dating_profile_service.dart';

class OnboardingState {
  const OnboardingState({
    required this.currentStep,
    required this.totalSteps,
    required this.displayName,
    required this.age,
    required this.dateOfBirth,
    required this.gender,
    required this.interestedIn,
    required this.country,
    required this.city,
    required this.bio,
    required this.profilePrompts,
    required this.remotePhotoUrls,
    required this.localPhotoBytes,
    this.isSubmitting = false,
    this.isDraftSaved = false,
  });

  final int currentStep;
  final int totalSteps;
  final String displayName;
  final int? age;
  final DateTime? dateOfBirth;
  final String gender;
  final List<String> interestedIn;
  final String country;
  final String city;
  final String bio;
  final List<ProfilePromptAnswer> profilePrompts;
  final List<String> remotePhotoUrls;
  final List<Uint8List> localPhotoBytes;
  final bool isSubmitting;
  final bool isDraftSaved;

  double get progress => currentStep / totalSteps;

  double get completionRatio {
    final checks = [
      displayName.trim().isNotEmpty,
      isAdult,
      gender.trim().isNotEmpty,
      interestedIn.isNotEmpty,
      country.trim().isNotEmpty,
      city.trim().isNotEmpty,
      remotePhotoUrls.isNotEmpty || localPhotoBytes.isNotEmpty,
      const DatingProfileService().normalizeBio(bio).isNotEmpty,
      const DatingProfileService().hasValidPromptAnswers(profilePrompts),
    ];
    return checks.where((value) => value).length / checks.length;
  }

  int get completionPercent => (completionRatio * 100).round();

  int? get derivedAge => dateOfBirth == null
      ? age
      : const AgePolicyService().ageOnDate(dateOfBirth!, DateTime.now());

  bool get isAdult => (derivedAge ?? 0) >= AgePolicyService.minimumDatingAge;

  bool get canContinueCurrentStep {
    switch (currentStep) {
      case 1:
        return displayName.trim().isNotEmpty && isAdult;
      case 2:
        return gender.trim().isNotEmpty && interestedIn.isNotEmpty;
      case 3:
        return country.trim().isNotEmpty && city.trim().isNotEmpty;
      case 4:
        return remotePhotoUrls.isNotEmpty || localPhotoBytes.isNotEmpty;
      case 5:
        return const DatingProfileService().normalizeBio(bio).length >= 20;
      case 6:
        return const DatingProfileService().hasValidPromptAnswers(
          profilePrompts,
        );
      case 7:
        return true;
      default:
        return false;
    }
  }

  AppUser toAppUser(AppUser baseUser, {List<String>? photoUrls}) {
    final resolvedPhotos = photoUrls ?? remotePhotoUrls;
    return baseUser.copyWith(
      displayName: displayName.trim(),
      age: age ?? baseUser.age,
      dateOfBirth: dateOfBirth ?? baseUser.dateOfBirth,
      gender: gender,
      interestedIn: interestedIn,
      country: country.trim(),
      city: city.trim(),
      bio: bio.trim(),
      profilePrompts: const DatingProfileService().normalizePromptAnswers(
        profilePrompts,
      ),
      datingProfileVersion: DatingProfileService.schemaVersion,
      photoUrl: resolvedPhotos.isNotEmpty
          ? resolvedPhotos.first
          : baseUser.photoUrl,
      photoUrls: resolvedPhotos,
      datingProfileComplete: completionRatio >= 1,
      requiredCompatibilityComplete: baseUser.requiredCompatibilityComplete,
      onboardingStep: completionRatio >= 1
          ? '/onboarding/questionnaire-one'
          : null,
      isProfileComplete:
          completionRatio >= 1 && baseUser.requiredCompatibilityComplete,
    );
  }

  factory OnboardingState.initial({AppUser? user}) {
    return OnboardingState(
      currentStep: 1,
      totalSteps: 7,
      displayName: user?.displayName ?? '',
      age: user?.age,
      dateOfBirth: user?.dateOfBirth,
      gender: user?.gender == 'unspecified' ? '' : (user?.gender ?? ''),
      interestedIn: user?.interestedIn ?? const [],
      country: user?.country ?? '',
      city: user?.city ?? '',
      bio: user?.bio ?? '',
      profilePrompts: user?.profilePrompts ?? const [],
      remotePhotoUrls: user?.photoUrls ?? const [],
      localPhotoBytes: const [],
    );
  }

  OnboardingState copyWith({
    int? currentStep,
    int? totalSteps,
    String? displayName,
    int? age,
    bool clearAge = false,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    String? gender,
    List<String>? interestedIn,
    String? country,
    String? city,
    String? bio,
    List<ProfilePromptAnswer>? profilePrompts,
    List<String>? remotePhotoUrls,
    List<Uint8List>? localPhotoBytes,
    bool? isSubmitting,
    bool? isDraftSaved,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      displayName: displayName ?? this.displayName,
      age: clearAge ? null : (age ?? this.age),
      dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      gender: gender ?? this.gender,
      interestedIn: interestedIn ?? this.interestedIn,
      country: country ?? this.country,
      city: city ?? this.city,
      bio: bio ?? this.bio,
      profilePrompts: profilePrompts ?? this.profilePrompts,
      remotePhotoUrls: remotePhotoUrls ?? this.remotePhotoUrls,
      localPhotoBytes: localPhotoBytes ?? this.localPhotoBytes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isDraftSaved: isDraftSaved ?? this.isDraftSaved,
    );
  }
}
