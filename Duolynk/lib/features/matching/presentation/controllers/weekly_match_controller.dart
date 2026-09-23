import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../services/analytics/analytics_event_service.dart';
import '../../../../services/matching/weekly_match_service.dart';
import '../../../subscription/data/subscription_repository.dart';
import '../../data/matching_repository.dart';
import '../../domain/weekly_match_state.dart';

final weeklyMatchServiceProvider = Provider<WeeklyMatchService>(
  (ref) => WeeklyMatchService(
    matchingRepository: ref.watch(matchingRepositoryProvider),
    subscriptionRepository: ref.watch(subscriptionRepositoryProvider),
    authService: ref.watch(firebaseAuthServiceProvider),
    notificationService: ref.watch(matchNotificationServiceProvider),
  ),
);

final weeklyMatchControllerProvider =
    AsyncNotifierProvider<WeeklyMatchController, WeeklyMatchState>(
      WeeklyMatchController.new,
    );

class WeeklyMatchController extends AsyncNotifier<WeeklyMatchState> {
  @override
  Future<WeeklyMatchState> build() async {
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<WeeklyMatchState> _load() async {
    final weeklyService = ref.read(weeklyMatchServiceProvider);
    await weeklyService.generateWeeklyMatchesIfNeeded();

    final repository = ref.read(matchingRepositoryProvider);
    final recommendations = await repository.fetchCuratedSuggestions();
    await weeklyService.queueDueIntroductionReminders();
    if (recommendations.isNotEmpty) {
      await const AnalyticsEventService().track('compatibility_details_viewed');
      await const AnalyticsEventService().track('curated_profile_viewed');
    }
    return WeeklyMatchState(
      suggestion: recommendations.isEmpty ? null : recommendations.first,
      recommendations: recommendations,
    );
  }

  Future<void> markInterested(String matchId) async {
    await const AnalyticsEventService().track('curated_match_interested');
    final result = await ref
        .read(matchingRepositoryProvider)
        .markInterestedWithResult(matchId);
    if (result.createdMutual) {
      await const AnalyticsEventService().track('mutual_match_created');
      final notificationService = ref.read(matchNotificationServiceProvider);
      for (final userId in result.match.participantIds) {
        await notificationService.queueMutualMatchNotification(
          userId: userId,
          match: result.match,
        );
      }
    }
    state = await AsyncValue.guard(_load);
  }

  Future<void> pass(String matchId) async {
    await const AnalyticsEventService().track('curated_match_passed');
    await ref.read(matchingRepositoryProvider).passMatch(matchId);
    state = await AsyncValue.guard(_load);
  }
}
