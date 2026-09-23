class AppRoutePaths {
  const AppRoutePaths._();

  static const String root = '/';
  static const String auth = '/auth';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';
  static const String onboarding = '/onboarding';
  static const String questionnaireOne = '/onboarding/questionnaire-one';
  static const String questionnaireTwo = '/onboarding/questionnaire-two';
  static const String questionnaireThree = '/onboarding/questionnaire-three';
  static const String questionnaireFour = '/onboarding/questionnaire-four';
  static const String questionnaireFive = '/onboarding/questionnaire-five';
  static const String matching = '/matching';
  static const String chat = '/chat';
  static const String chatThreadPattern = '/chat/:chatId';
  static const String profile = '/profile';
  static const String profileEdit = '/profile/edit';
  static const String profilePreview = '/profile/preview';
  static const String settings = '/profile/settings';
  static const String compatibilityProfile = '/profile/compatibility-profile';
  static const String notificationSettings = '/profile/settings/notifications';
  static const String safetyCenter = '/profile/settings/safety';
  static const String privacyPolicy = '/profile/settings/privacy-policy';
  static const String terms = '/profile/settings/terms';
  static const String subscription = '/subscription';

  static String chatThread(String chatId) => '/chat/$chatId';
}
