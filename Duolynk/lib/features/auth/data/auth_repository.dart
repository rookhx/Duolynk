import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/config/firestore_paths.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/app_user.dart';
import '../../../services/firebase/firebase_auth_service.dart';
import '../../../services/firebase/firestore_service.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    authService: ref.watch(firebaseAuthServiceProvider),
    firestoreService: ref.watch(firestoreServiceProvider),
  ),
);

class AuthRepository {
  const AuthRepository({
    required FirebaseAuthService authService,
    required FirestoreService firestoreService,
  }) : _authService = authService,
       _firestoreService = firestoreService;

  final FirebaseAuthService _authService;
  final FirestoreService _firestoreService;

  Stream<AppUser?> watchAuthState() {
    return _authService.authStateChanges().asyncMap((user) async {
      if (user == null) {
        return null;
      }

      final snapshot = await _firestoreService.getDocument(
        FirestorePaths.user(user.uid),
      );

      if (snapshot.exists && snapshot.data() != null) {
        return AppUser.fromMap(snapshot.id, snapshot.data()!);
      }

      final profile = _buildUserFromAuthUser(
        user.uid,
        user.email,
        user.displayName,
      );
      await _firestoreService.setDocument(
        FirestorePaths.user(user.uid),
        profile.toMap(),
      );
      return profile;
    });
  }

  Future<AppUser> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _authService.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final userId = credential.user!.uid;
    final profile = _buildUserFromAuthUser(userId, email, displayName);
    await _firestoreService.setDocument(
      FirestorePaths.user(userId),
      profile.toMap(),
    );
    return profile;
  }

  Future<AppUser?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _authService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user?.uid;
    if (uid == null) {
      return null;
    }

    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.user(uid),
    );
    if (!snapshot.exists || snapshot.data() == null) {
      final fallback = _buildUserFromAuthUser(
        uid,
        credential.user?.email,
        credential.user?.displayName,
      );
      await _firestoreService.setDocument(
        FirestorePaths.user(uid),
        fallback.toMap(),
      );
      return fallback;
    }

    return AppUser.fromMap(uid, snapshot.data()!);
  }

  Future<AppUser> signInWithGoogle() async {
    final credential = await _authService.signInWithGoogle();
    return _upsertFromCredential(credential);
  }

  Future<AppUser> signInWithApple() async {
    final credential = await _authService.signInWithApple();
    return _upsertFromCredential(credential);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _authService.sendPasswordResetEmail(email);
  }

  Future<void> signOut() => _authService.signOut();

  Future<AppUser> _upsertFromCredential(UserCredential credential) async {
    final user = credential.user;
    if (user == null) {
      throw StateError('Authentication succeeded without a Firebase user.');
    }

    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.user(user.uid),
    );

    if (snapshot.exists && snapshot.data() != null) {
      final existing = AppUser.fromMap(snapshot.id, snapshot.data()!);
      final merged = existing.copyWith(
        email: user.email ?? existing.email,
        displayName: user.displayName ?? existing.displayName,
        photoUrl: user.photoURL ?? existing.photoUrl,
        updatedAt: DateTime.now(),
      );
      await _firestoreService.setDocument(
        FirestorePaths.user(user.uid),
        merged.toEditableMap(),
      );
      return merged;
    }

    final profile = _buildUserFromAuthUser(
      user.uid,
      user.email,
      user.displayName,
      photoUrl: user.photoURL,
    );
    await _firestoreService.setDocument(
      FirestorePaths.user(user.uid),
      profile.toMap(),
    );
    return profile;
  }

  AppUser _buildUserFromAuthUser(
    String uid,
    String? email,
    String? displayName, {
    String? photoUrl,
  }) {
    final now = DateTime.now();
    return AppUser(
      id: uid,
      email: email ?? '',
      displayName: displayName ?? 'Duolynk Member',
      age: 18,
      gender: 'unspecified',
      interestedIn: const [],
      createdAt: now,
      updatedAt: now,
      country: null,
      city: null,
      photoUrl: photoUrl,
      photoUrls: photoUrl == null ? const [] : [photoUrl],
      isProfileComplete: false,
      datingProfileComplete: false,
      requiredCompatibilityComplete: false,
      onboardingStep: '/onboarding',
    );
  }
}
