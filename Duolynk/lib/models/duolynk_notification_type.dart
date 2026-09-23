enum DuolynkNotificationType {
  curatedIntroduction('curated_introduction'),
  introductionReminder('introduction_reminder'),
  mutualMatch('mutual_match'),
  newMessage('new_message'),
  lockedMatchMessage('locked_match_message'),
  accountSafety('account_safety');

  const DuolynkNotificationType(this.id);

  final String id;

  static DuolynkNotificationType fromId(String? id) {
    return DuolynkNotificationType.values.firstWhere(
      (type) => type.id == id || type.name == id,
      orElse: () => DuolynkNotificationType.accountSafety,
    );
  }
}
