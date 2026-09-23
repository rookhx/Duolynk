import '../../../models/app_user.dart';

class ProfileState {
  const ProfileState({
    this.user,
    this.completion = 0,
    this.compatibilityCompletion = 0,
    this.isSaving = false,
  });

  final AppUser? user;
  final double completion;
  final double compatibilityCompletion;
  final bool isSaving;

  ProfileState copyWith({
    AppUser? user,
    double? completion,
    double? compatibilityCompletion,
    bool? isSaving,
  }) {
    return ProfileState(
      user: user ?? this.user,
      completion: completion ?? this.completion,
      compatibilityCompletion:
          compatibilityCompletion ?? this.compatibilityCompletion,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
