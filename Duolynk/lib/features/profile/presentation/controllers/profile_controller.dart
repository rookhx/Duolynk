import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/app_user.dart';
import '../../../../services/matching/compatibility_profile_completion_service.dart';
import '../../../onboarding/data/onboarding_repository.dart';
import '../../data/profile_repository.dart';
import '../../domain/profile_state.dart';

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, ProfileState>(
      ProfileController.new,
    );

class ProfileController extends AsyncNotifier<ProfileState> {
  @override
  Future<ProfileState> build() async {
    final user = await ref.read(profileRepositoryProvider).fetchProfile();
    return ProfileState(
      user: user,
      completion: user?.completionRatio ?? 0,
      compatibilityCompletion: await _compatibilityCompletion(),
    );
  }

  Future<void> refreshProfile() async {
    final user = await ref.read(profileRepositoryProvider).fetchProfile();
    state = AsyncData(
      ProfileState(
        user: user,
        completion: user?.completionRatio ?? 0,
        compatibilityCompletion: await _compatibilityCompletion(),
      ),
    );
  }

  Future<void> saveProfile(AppUser user) async {
    state = AsyncData(state.requireValue.copyWith(isSaving: true));
    try {
      await ref.read(onboardingRepositoryProvider).saveProfile(user);
      final refreshed = await ref
          .read(profileRepositoryProvider)
          .fetchProfile();
      state = AsyncData(
        ProfileState(
          user: refreshed,
          completion: refreshed?.completionRatio ?? 0,
          compatibilityCompletion: await _compatibilityCompletion(),
          isSaving: false,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<double> _compatibilityCompletion() async {
    final questionnaires = await ref
        .read(onboardingRepositoryProvider)
        .fetchQuestionnaires();
    return const CompatibilityProfileCompletionService().calculate(
      questionnaires,
    );
  }
}
