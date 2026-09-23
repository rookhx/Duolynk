import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/config/compatibility_question_schema.dart';
import '../../../core/config/firestore_paths.dart';
import '../../../core/demo/demo_store.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/app_user.dart';
import '../../../models/questionnaire_model.dart';
import '../../../services/firebase/firebase_auth_service.dart';
import '../../../services/firebase/firestore_service.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(
    firestoreService: ref.watch(firestoreServiceProvider),
    authService: ref.watch(firebaseAuthServiceProvider),
  ),
);

class OnboardingRepository {
  const OnboardingRepository({
    required FirestoreService firestoreService,
    required FirebaseAuthService authService,
  }) : _firestoreService = firestoreService,
       _authService = authService;

  final FirestoreService _firestoreService;
  final FirebaseAuthService _authService;

  Future<QuestionnaireModel?> fetchDraft({
    String questionnaireId = 'primary',
  }) async {
    if (!AppEnvironment.firebaseEnabled) {
      return DemoStore.questionnaireById(questionnaireId);
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return null;
    }

    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.userQuestionnaire(userId, questionnaireId),
    );
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return QuestionnaireModel.fromMap(snapshot.id, snapshot.data()!);
  }

  Future<List<QuestionnaireModel>> fetchQuestionnaires() async {
    if (!AppEnvironment.firebaseEnabled) {
      return DemoStore.questionnaires.values.toList();
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return const [];
    }

    final snapshot = await _firestoreService.getCollection(
      FirestorePaths.userQuestionnaires(userId),
    );
    return snapshot.docs
        .map((doc) => QuestionnaireModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<QuestionnaireModel> persistDraft({
    required Map<String, dynamic> answers,
    required int completedSteps,
    required int totalSteps,
    String questionnaireId = 'primary',
    bool isComplete = false,
  }) async {
    if (!AppEnvironment.firebaseEnabled) {
      final now = DateTime.now();
      final existing = DemoStore.questionnaireById(questionnaireId);
      final draft = QuestionnaireModel(
        id: questionnaireId,
        userId: DemoStore.user.id,
        answers: answers,
        completedSteps: completedSteps,
        totalSteps: totalSteps,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        isComplete: isComplete,
        questionnaireVersion: CompatibilityQuestionSchema.questionnaireVersion,
      );
      DemoStore.saveQuestionnaire(draft);
      return draft;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      throw StateError(
        'A signed-in user is required to persist questionnaire data.',
      );
    }

    final now = DateTime.now();
    final existing = await fetchDraft(questionnaireId: questionnaireId);
    final draft = QuestionnaireModel(
      id: questionnaireId,
      userId: userId,
      answers: answers,
      completedSteps: completedSteps,
      totalSteps: totalSteps,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      isComplete: isComplete,
      questionnaireVersion: CompatibilityQuestionSchema.questionnaireVersion,
    );

    await _firestoreService.setDocument(
      FirestorePaths.userQuestionnaire(userId, questionnaireId),
      draft.toMap(),
    );
    return draft;
  }

  Future<AppUser?> fetchCurrentProfile() async {
    if (!AppEnvironment.firebaseEnabled) {
      return DemoStore.user;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return null;
    }

    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.user(userId),
    );
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return AppUser.fromMap(snapshot.id, snapshot.data()!);
  }

  Future<AppUser> saveProfile(AppUser profile) async {
    if (!AppEnvironment.firebaseEnabled) {
      final normalized = profile.copyWith(
        photoUrl: profile.photoUrls.isNotEmpty
            ? profile.photoUrls.first
            : profile.photoUrl,
        isProfileComplete: profile.datingProfileVersion == 0
            ? profile.isProfileComplete
            : profile.completionRatio >= 1,
        updatedAt: DateTime.now(),
      );
      DemoStore.saveUser(normalized);
      return normalized;
    }

    final normalized = profile.copyWith(
      photoUrl: profile.photoUrls.isNotEmpty
          ? profile.photoUrls.first
          : profile.photoUrl,
      isProfileComplete: profile.datingProfileVersion == 0
          ? profile.isProfileComplete
          : profile.completionRatio >= 1,
      updatedAt: DateTime.now(),
    );

    await _firestoreService.setDocument(
      FirestorePaths.user(normalized.id),
      normalized.toEditableMap(),
    );
    return normalized;
  }
}
