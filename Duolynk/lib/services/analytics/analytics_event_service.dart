class AnalyticsEventService {
  const AnalyticsEventService();

  Future<void> track(
    String eventName, {
    Map<String, Object?> parameters = const {},
  }) async {
    // Centralized no-op for now. Firebase Analytics is configured in the app,
    // but event taxonomy can be wired here later without scattering calls or
    // logging private questionnaire answers/message content.
  }
}
