import '../../core/config/profile_prompt_library.dart';
import '../../models/app_user.dart';
import '../../models/profile_prompt_answer.dart';

class DatingProfileService {
  const DatingProfileService();

  static const int schemaVersion = 1;
  static const int maxPhotoCount = 6;
  static const int bioCharacterLimit = 500;

  List<ProfilePromptAnswer> normalizePromptAnswers(
    List<ProfilePromptAnswer> answers,
  ) {
    final seen = <String>{};
    final normalized = <ProfilePromptAnswer>[];
    for (final answer in answers) {
      final promptId = answer.promptId.trim();
      final text = answer.answer.trim();
      if (promptId.isEmpty ||
          text.isEmpty ||
          seen.contains(promptId) ||
          ProfilePromptLibrary.byId(promptId) == null) {
        continue;
      }
      seen.add(promptId);
      normalized.add(
        ProfilePromptAnswer(
          promptId: promptId,
          answer: text.length > ProfilePromptLibrary.answerCharacterLimit
              ? text.substring(0, ProfilePromptLibrary.answerCharacterLimit)
              : text,
        ),
      );
    }
    return normalized.take(ProfilePromptLibrary.requiredPromptCount).toList();
  }

  String normalizeBio(String bio) {
    final trimmed = bio.trim();
    return trimmed.length > bioCharacterLimit
        ? trimmed.substring(0, bioCharacterLimit)
        : trimmed;
  }

  List<String> normalizePhotos(List<String> photos) {
    final seen = <String>{};
    return photos
        .map((photo) => photo.trim())
        .where((photo) => photo.isNotEmpty)
        .where((photo) => seen.add(photo))
        .take(maxPhotoCount)
        .toList();
  }

  bool hasValidPromptAnswers(List<ProfilePromptAnswer> answers) {
    final normalized = normalizePromptAnswers(answers);
    return normalized.length == ProfilePromptLibrary.requiredPromptCount;
  }

  double completionFor(AppUser user) {
    final checks = [
      user.displayName.trim().isNotEmpty,
      user.isAdult,
      user.gender.trim().isNotEmpty && user.gender != 'unspecified',
      user.interestedIn.isNotEmpty,
      user.country?.trim().isNotEmpty ?? false,
      user.city?.trim().isNotEmpty ?? false,
      normalizePhotos(user.photoUrls).isNotEmpty ||
          (user.photoUrl?.trim().isNotEmpty ?? false),
      normalizeBio(user.bio ?? '').isNotEmpty,
      hasValidPromptAnswers(user.profilePrompts),
    ];
    return checks.where((value) => value).length / checks.length;
  }

  bool isCompleteForNewProfile(AppUser user) => completionFor(user) >= 1;

  String relationshipIntentionLabel(Map<String, String> relationshipGoals) {
    final marriage = _normalize(relationshipGoals['marriage']);
    final longTerm = _normalize(relationshipGoals['longTermRelationship']);
    final casual = _normalize(relationshipGoals['casualDating']);

    if (longTerm == 'essential' || marriage == 'definitely want it') {
      return 'Looking for a serious relationship';
    }
    if (longTerm == 'very important' || marriage == 'open to it') {
      return 'Open to a long-term relationship';
    }
    if (casual == 'prefer casual right now') {
      return 'Keeping dating casual right now';
    }
    if (casual == 'comfortable with it' ||
        casual == 'depends on the person' ||
        longTerm == 'open to it') {
      return 'Open to seeing where the connection goes';
    }
    if (longTerm == 'not sure yet' || marriage == 'unsure') {
      return 'Still figuring out the right relationship pace';
    }
    if (longTerm == 'not looking for that' || marriage == 'do not want it') {
      return 'Not focused on traditional long-term milestones';
    }
    return '';
  }

  List<String> publicInterestPreview(List<String> interests, {int limit = 8}) {
    final seen = <String>{};
    return interests
        .map((interest) => interest.trim())
        .where((interest) => interest.isNotEmpty)
        .where((interest) => seen.add(interest.toLowerCase()))
        .take(limit)
        .toList();
  }

  String? promptValidationError(
    List<ProfilePromptAnswer> answers, {
    bool requireExactlyThree = true,
  }) {
    if (answers.map((answer) => answer.promptId).toSet().length !=
        answers.length) {
      return 'Choose each prompt only once.';
    }
    if (answers.any((answer) => answer.answer.trim().isEmpty)) {
      return 'Prompt answers cannot be blank.';
    }
    if (answers.any(
      (answer) =>
          answer.answer.trim().length >
          ProfilePromptLibrary.answerCharacterLimit,
    )) {
      return 'Prompt answers must be ${ProfilePromptLibrary.answerCharacterLimit} characters or fewer.';
    }
    final normalized = normalizePromptAnswers(answers);
    if (requireExactlyThree &&
        normalized.length != ProfilePromptLibrary.requiredPromptCount) {
      return 'Choose 3 prompts and answer each one.';
    }
    return null;
  }

  String? _normalize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim().toLowerCase();
  }
}
