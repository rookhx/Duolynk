import '../../models/weekly_match_generation_result.dart';
import '../firebase/firebase_auth_service.dart';
import 'match_notification_service.dart';
import '../../features/matching/data/matching_repository.dart';
import '../../features/subscription/data/subscription_repository.dart';

class WeeklyMatchService {
  const WeeklyMatchService({
    required MatchingRepository matchingRepository,
    required SubscriptionRepository subscriptionRepository,
    required FirebaseAuthService authService,
    required MatchNotificationService notificationService,
  }) : _matchingRepository = matchingRepository,
       _subscriptionRepository = subscriptionRepository,
       _authService = authService,
       _notificationService = notificationService;

  final MatchingRepository _matchingRepository;
  final SubscriptionRepository _subscriptionRepository;
  final FirebaseAuthService _authService;
  final MatchNotificationService _notificationService;

  Future<WeeklyMatchGenerationResult> generateWeeklyMatchesIfNeeded() async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      return const WeeklyMatchGenerationResult(
        generatedMatches: [],
        remainingQuota: 0,
        weekKey: '',
      );
    }
    if (!await _matchingRepository.canCurrentUserReceiveNewIntroductions()) {
      return const WeeklyMatchGenerationResult(
        generatedMatches: [],
        remainingQuota: 0,
        weekKey: '',
      );
    }

    final subscription = await _subscriptionRepository.fetchStatus();
    final now = DateTime.now().toUtc();
    final weekKey = _weekKey(now);

    final existingThisWeek = await _matchingRepository
        .fetchGeneratedMatchesForWeek(userId: userId, weekKey: weekKey);
    final remainingQuota =
        subscription.weeklyCandidateLimit - existingThisWeek.length;
    if (remainingQuota <= 0) {
      return WeeklyMatchGenerationResult(
        generatedMatches: const [],
        remainingQuota: 0,
        weekKey: weekKey,
      );
    }

    final generation = await _matchingRepository
        .generateWeeklyCuratedCandidates();
    final generatedThisWeek = await _matchingRepository
        .fetchGeneratedMatchesForWeek(userId: userId, weekKey: weekKey);

    if (generatedThisWeek.isEmpty) {
      return WeeklyMatchGenerationResult(
        generatedMatches: const [],
        remainingQuota: remainingQuota,
        weekKey: weekKey,
      );
    }

    final generatedIds =
        (generation['matchIds'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .toSet();
    final newlyGenerated = generatedThisWeek
        .where((match) => generatedIds.contains(match.id))
        .toList();

    for (final match in newlyGenerated) {
      await _notificationService.queueNewMatchNotification(
        userId: userId,
        match: match,
      );
    }

    return WeeklyMatchGenerationResult(
      generatedMatches: newlyGenerated,
      remainingQuota:
          subscription.weeklyCandidateLimit - generatedThisWeek.length,
      weekKey: weekKey,
    );
  }

  Future<void> queueDueIntroductionReminders() async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      return;
    }
    final suggestions = await _matchingRepository.fetchCuratedSuggestions();
    final now = DateTime.now().toUtc();
    for (final suggestion in suggestions) {
      await _notificationService.queueIntroductionReminderIfEligible(
        userId: userId,
        match: suggestion.match,
        now: now,
      );
    }
  }

  DateTime _startOfWeekUtc(DateTime date) {
    final normalized = DateTime.utc(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  String _weekKey(DateTime date) {
    final start = _startOfWeekUtc(date);
    final end = start.add(const Duration(days: 6));
    return '${start.year}-${_two(start.month)}-${_two(start.day)}_${end.year}-${_two(end.month)}-${_two(end.day)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
