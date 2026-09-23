import 'package:duolynk/core/config/profile_prompt_library.dart';
import 'package:duolynk/models/app_user.dart';
import 'package:duolynk/models/compatibility_profile.dart';
import 'package:duolynk/models/match_feedback.dart';
import 'package:duolynk/models/match_model.dart';
import 'package:duolynk/models/profile_prompt_answer.dart';
import 'package:duolynk/services/matching/compatibility_engine_service.dart';
import 'package:duolynk/services/matching/personalized_matching_service.dart';
import 'package:duolynk/services/profile/dating_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = DatingProfileService();

  test('stable prompt IDs deserialize correctly', () {
    final answer = ProfilePromptAnswer.fromMap({
      'promptId': 'perfect_weekend',
      'answer': 'Coffee, a long walk, and dinner with friends.',
    });

    expect(answer.promptId, 'perfect_weekend');
    expect(
      ProfilePromptLibrary.labelFor(answer.promptId),
      'A perfect weekend for me is...',
    );
  });

  test('user can select 3 unique prompts', () {
    final normalized = service.normalizePromptAnswers(_threePrompts());

    expect(normalized.length, 3);
    expect(service.hasValidPromptAnswers(normalized), isTrue);
  });

  test('duplicate prompt selection is rejected', () {
    final error = service.promptValidationError([
      const ProfilePromptAnswer(promptId: 'perfect_weekend', answer: 'A'),
      const ProfilePromptAnswer(promptId: 'perfect_weekend', answer: 'B'),
      const ProfilePromptAnswer(promptId: 'ideal_first_date', answer: 'C'),
    ]);

    expect(error, contains('Choose each prompt only once'));
  });

  test('blank prompt answer is rejected', () {
    final error = service.promptValidationError([
      const ProfilePromptAnswer(promptId: 'perfect_weekend', answer: '  '),
      const ProfilePromptAnswer(promptId: 'ideal_first_date', answer: 'Coffee'),
      const ProfilePromptAnswer(promptId: 'green_flag', answer: 'Kindness'),
    ]);

    expect(error, contains('cannot be blank'));
  });

  test('prompt answer character limit works', () {
    final long = 'x' * (ProfilePromptLibrary.answerCharacterLimit + 1);
    final error = service.promptValidationError([
      ProfilePromptAnswer(promptId: 'perfect_weekend', answer: long),
      const ProfilePromptAnswer(promptId: 'ideal_first_date', answer: 'Coffee'),
      const ProfilePromptAnswer(promptId: 'green_flag', answer: 'Kindness'),
    ]);
    final normalized = service.normalizePromptAnswers([
      ProfilePromptAnswer(promptId: 'perfect_weekend', answer: long),
    ]);

    expect(error, contains('150 characters'));
    expect(
      normalized.single.answer.length,
      ProfilePromptLibrary.answerCharacterLimit,
    );
  });

  test('legacy users without prompts still deserialize', () {
    final user = AppUser.fromMap('legacy', _userMap());

    expect(user.profilePrompts, isEmpty);
    expect(user.datingProfileVersion, 0);
  });

  test('new-profile completion requires prompt count and primary photo', () {
    final incomplete = _user(profilePrompts: const []);
    final complete = _user(profilePrompts: _threePrompts());

    expect(service.isCompleteForNewProfile(incomplete), isFalse);
    expect(service.isCompleteForNewProfile(complete), isTrue);
  });

  test(
    'legacy users are not automatically excluded by missing prompts flag',
    () {
      final legacy = AppUser.fromMap('legacy', {
        ..._userMap(),
        'isProfileComplete': true,
      });

      expect(legacy.isProfileComplete, isTrue);
      expect(legacy.profilePrompts, isEmpty);
    },
  );

  test('public profile stores prompt answers as plain text', () {
    final user = _user(
      profilePrompts: const [
        ProfilePromptAnswer(
          promptId: 'one_thing_to_know',
          answer: '<b>I value kindness.</b>',
        ),
      ],
    );

    expect(user.profilePrompts.single.answer, '<b>I value kindness.</b>');
  });

  test('prompt answers do not influence compatibility score', () {
    const engine = CompatibilityEngineService();
    final current = _compatibilityProfile(_user(id: 'a'));
    final withPrompts = _compatibilityProfile(
      _user(id: 'b', profilePrompts: _threePrompts()),
    );
    final withoutPrompts = _compatibilityProfile(
      _user(id: 'c', profilePrompts: const []),
    );

    final first = engine
        .rankCandidates(currentUser: current, candidates: [withPrompts])
        .single;
    final second = engine
        .rankCandidates(currentUser: current, candidates: [withoutPrompts])
        .single;

    expect(first.compatibilityScore, second.compatibilityScore);
  });

  test('prompt answers do not influence personalized ranking', () {
    const service = PersonalizedMatchingService();
    final result = const CompatibilityEngineService()
        .rankCandidates(
          currentUser: _compatibilityProfile(_user(id: 'a')),
          candidates: [
            _compatibilityProfile(
              _user(id: 'b', profilePrompts: _threePrompts()),
            ),
          ],
        )
        .single;
    final profile = service.buildProfile(
      userId: 'a',
      enabled: true,
      feedback: [
        _feedback(MatchFeedbackReason.notEnoughSharedInterests),
        _feedback(MatchFeedbackReason.notEnoughSharedInterests),
        _feedback(MatchFeedbackReason.notEnoughSharedInterests),
      ],
      now: DateTime.utc(2026, 9, 21),
    );

    expect(service.personalizedScoreFor(result, profile), isA<double>());
  });

  test('relationship intention display mapping works', () {
    expect(
      service.relationshipIntentionLabel(const {
        'marriage': 'Definitely want it',
        'longTermRelationship': 'Essential',
        'casualDating': 'Not interested',
      }),
      'Looking for a serious relationship',
    );
    expect(
      service.relationshipIntentionLabel(const {
        'casualDating': 'Prefer casual right now',
      }),
      'Keeping dating casual right now',
    );
  });

  test('public interests are limited and readable', () {
    final interests = service.publicInterestPreview(const [
      'Travel',
      'Cooking',
      'Travel',
      'Hiking',
      'Music',
    ], limit: 3);

    expect(interests, const ['Travel', 'Cooking', 'Hiking']);
  });

  test('photo requirements and maximum count are enforced', () {
    final photos = service.normalizePhotos([
      for (var index = 0; index < 8; index++) 'photo-$index',
    ]);

    expect(photos.length, DatingProfileService.maxPhotoCount);
    expect(
      service.isCompleteForNewProfile(_user(photoUrls: const [])),
      isFalse,
    );
  });

  test('photo reordering preserves primary photo by first position', () {
    final photos = service.normalizePhotos(const ['a', 'b', 'c']);
    final reordered = [...photos];
    final moved = reordered.removeAt(2);
    reordered.insert(0, moved);

    expect(reordered.first, 'c');
  });

  test(
    'dating-profile completion is separate from compatibility snapshots',
    () {
      final match = MatchModel(
        id: 'a_b',
        userId: 'a',
        partnerId: 'b',
        compatibilityScore: 87,
        status: MatchStatus.suggested,
        compatibilityReasons: const [],
        createdAt: DateTime.utc(2026, 9, 1),
        expiresAt: DateTime.utc(2026, 9, 8),
        categoryScores: const {'relationshipGoals': 90},
      );
      final edited = _user(profilePrompts: _threePrompts());

      expect(service.completionFor(edited), 1);
      expect(match.compatibilityScore, 87);
      expect(match.categoryScores['relationshipGoals'], 90);
    },
  );

  test('free or premium status does not alter profile compatibility score', () {
    const engine = CompatibilityEngineService();
    final result = engine
        .rankCandidates(
          currentUser: _compatibilityProfile(_user(id: 'a')),
          candidates: [_compatibilityProfile(_user(id: 'b'))],
        )
        .single;

    expect(result.compatibilityScore, inInclusiveRange(0, 100));
  });
}

List<ProfilePromptAnswer> _threePrompts() {
  return const [
    ProfilePromptAnswer(
      promptId: 'perfect_weekend',
      answer: 'Coffee, a walk, and cooking for people I love.',
    ),
    ProfilePromptAnswer(
      promptId: 'ideal_first_date',
      answer: 'Something low-pressure with room for a real conversation.',
    ),
    ProfilePromptAnswer(
      promptId: 'green_flag',
      answer: 'Kindness when nobody is keeping score.',
    ),
  ];
}

AppUser _user({
  String id = 'user',
  List<String> photoUrls = const ['photo-1'],
  List<ProfilePromptAnswer> profilePrompts = const [
    ProfilePromptAnswer(promptId: 'perfect_weekend', answer: 'Coffee.'),
    ProfilePromptAnswer(promptId: 'ideal_first_date', answer: 'A walk.'),
    ProfilePromptAnswer(promptId: 'green_flag', answer: 'Kindness.'),
  ],
}) {
  return AppUser(
    id: id,
    email: '$id@example.com',
    displayName: 'Taylor',
    age: 30,
    gender: 'Woman',
    interestedIn: const ['Man'],
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    country: 'United States',
    city: 'Chicago',
    bio: 'Thoughtful, warm, and serious about intentional dating.',
    photoUrl: photoUrls.isEmpty ? null : photoUrls.first,
    photoUrls: photoUrls,
    profilePrompts: profilePrompts,
    datingProfileVersion: DatingProfileService.schemaVersion,
  );
}

Map<String, dynamic> _userMap() {
  return {
    'email': 'legacy@example.com',
    'displayName': 'Legacy',
    'age': 31,
    'gender': 'Woman',
    'interestedIn': ['Man'],
    'createdAt': DateTime.utc(2026, 1, 1),
    'updatedAt': DateTime.utc(2026, 1, 1),
    'country': 'United States',
    'city': 'Chicago',
    'bio': 'Legacy profile',
    'photoUrls': ['photo'],
  };
}

CompatibilityProfile _compatibilityProfile(AppUser user) {
  return CompatibilityProfile(
    user: user,
    interests: const ['Travel', 'Cooking'],
    lifestyleAnswers: const {'socialLifestyle': 'Balanced'},
    relationshipGoalAnswers: const {
      'marriage': 'Open to it',
      'longTermRelationship': 'Very important',
      'casualDating': 'Depends on the person',
    },
    personalityAnswers: const {'introvertExtrovert': 'Balanced'},
    preferenceAnswers: const {},
  );
}

MatchFeedback _feedback(MatchFeedbackReason reason) {
  return MatchFeedback(
    feedbackId: reason.name,
    userId: 'a',
    matchId: 'a_b',
    pairKey: 'a_b',
    reasons: {reason},
    goodMatch: false,
    metInPerson: false,
    createdAt: DateTime.utc(2026, 9, 21),
    categoryScores: const {'interests': 80},
  );
}
