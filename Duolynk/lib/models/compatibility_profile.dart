import 'app_user.dart';

class CompatibilityProfile {
  const CompatibilityProfile({
    required this.user,
    required this.interests,
    required this.lifestyleAnswers,
    required this.relationshipGoalAnswers,
    required this.personalityAnswers,
    required this.preferenceAnswers,
    this.optionalAnswers = const {},
  });

  final AppUser user;
  final List<String> interests;
  final Map<String, String> lifestyleAnswers;
  final Map<String, String> relationshipGoalAnswers;
  final Map<String, String> personalityAnswers;
  final Map<String, dynamic> preferenceAnswers;
  final Map<String, dynamic> optionalAnswers;
}
