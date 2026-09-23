class AgePolicyService {
  const AgePolicyService();

  static const int minimumDatingAge = 18;

  int ageOnDate(DateTime dateOfBirth, DateTime onDate) {
    var age = onDate.year - dateOfBirth.year;
    final hasHadBirthdayThisYear =
        onDate.month > dateOfBirth.month ||
        (onDate.month == dateOfBirth.month && onDate.day >= dateOfBirth.day);
    if (!hasHadBirthdayThisYear) {
      age -= 1;
    }
    return age;
  }

  bool isAdult(DateTime dateOfBirth, {DateTime? now}) {
    return ageOnDate(dateOfBirth, now ?? DateTime.now()) >= minimumDatingAge;
  }
}
