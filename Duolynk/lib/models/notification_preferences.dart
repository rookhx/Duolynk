class NotificationPreferences {
  const NotificationPreferences({
    this.newIntroductions = true,
    this.matchUpdates = true,
    this.messages = true,
    this.reminders = true,
    this.marketing = false,
    this.weeklyInsights = true,
    this.pushEnabled = true,
  });

  final bool newIntroductions;
  final bool matchUpdates;
  final bool messages;
  final bool reminders;
  final bool marketing;
  final bool weeklyInsights;
  final bool pushEnabled;

  NotificationPreferences copyWith({
    bool? newIntroductions,
    bool? matchUpdates,
    bool? messages,
    bool? reminders,
    bool? marketing,
    bool? weeklyInsights,
    bool? pushEnabled,
  }) {
    return NotificationPreferences(
      newIntroductions: newIntroductions ?? this.newIntroductions,
      matchUpdates: matchUpdates ?? this.matchUpdates,
      messages: messages ?? this.messages,
      reminders: reminders ?? this.reminders,
      marketing: marketing ?? this.marketing,
      weeklyInsights: weeklyInsights ?? this.weeklyInsights,
      pushEnabled: pushEnabled ?? this.pushEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pushEnabled': pushEnabled,
      'newIntroductions': newIntroductions,
      'newMatches': newIntroductions,
      'matchUpdates': matchUpdates,
      'messages': messages,
      'reminders': reminders,
      'marketing': marketing,
      'weeklyInsights': weeklyInsights,
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    final legacyNewMatches = map['newMatches'] as bool?;
    return NotificationPreferences(
      pushEnabled: map['pushEnabled'] as bool? ?? true,
      newIntroductions:
          map['newIntroductions'] as bool? ?? legacyNewMatches ?? true,
      matchUpdates: map['matchUpdates'] as bool? ?? legacyNewMatches ?? true,
      messages: map['messages'] as bool? ?? true,
      reminders:
          map['reminders'] as bool? ?? map['weeklyInsights'] as bool? ?? true,
      marketing: map['marketing'] as bool? ?? false,
      weeklyInsights: map['weeklyInsights'] as bool? ?? true,
    );
  }
}
