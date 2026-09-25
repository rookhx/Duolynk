import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/profile_prompt_library.dart';
import '../services/safety/age_policy_service.dart';
import 'profile_prompt_answer.dart';

enum DatingStatus { active, paused }

enum ModerationStatus { active, underReview, suspended, banned }

enum VerificationStatus { unverified, pending, verified, rejected }

enum PhotoModerationStatus { pending, approved, rejected }

enum ProfileTextModerationStatus { pending, approved, rejected }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.age,
    required this.gender,
    required this.interestedIn,
    required this.createdAt,
    required this.updatedAt,
    this.dateOfBirth,
    this.bio,
    this.country,
    this.city,
    this.photoUrl,
    this.photoUrls = const [],
    this.profilePrompts = const [],
    this.datingProfileVersion = 1,
    this.datingStatus = DatingStatus.active,
    this.datingPausedAt,
    this.moderationStatus = ModerationStatus.active,
    this.verificationStatus = VerificationStatus.unverified,
    this.photoModerationStatuses = const {},
    this.bioModerationStatus = ProfileTextModerationStatus.approved,
    this.promptModerationStatuses = const {},
    this.isProfileComplete = false,
    this.datingProfileComplete = true,
    this.requiredCompatibilityComplete = true,
    this.onboardingStep,
    this.notificationToken,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String email;
  final String displayName;
  final int age;
  final String gender;
  final List<String> interestedIn;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dateOfBirth;
  final String? bio;
  final String? country;
  final String? city;
  final String? photoUrl;
  final List<String> photoUrls;
  final List<ProfilePromptAnswer> profilePrompts;
  final int datingProfileVersion;
  final DatingStatus datingStatus;
  final DateTime? datingPausedAt;
  final ModerationStatus moderationStatus;
  final VerificationStatus verificationStatus;
  final Map<String, PhotoModerationStatus> photoModerationStatuses;
  final ProfileTextModerationStatus bioModerationStatus;
  final Map<String, ProfileTextModerationStatus> promptModerationStatuses;
  final bool isProfileComplete;
  final bool datingProfileComplete;
  final bool requiredCompatibilityComplete;
  final String? onboardingStep;
  final String? notificationToken;
  final double? latitude;
  final double? longitude;

  double get completionRatio {
    final validPrompts = profilePrompts
        .where(
          (prompt) =>
              prompt.promptId.trim().isNotEmpty &&
              prompt.answer.trim().isNotEmpty &&
              prompt.answer.trim().length <=
                  ProfilePromptLibrary.answerCharacterLimit,
        )
        .map((prompt) => prompt.promptId)
        .toSet()
        .length;
    final checks = [
      displayName.trim().isNotEmpty,
      isAdult,
      gender.trim().isNotEmpty && gender != 'unspecified',
      interestedIn.isNotEmpty,
      country?.trim().isNotEmpty ?? false,
      city?.trim().isNotEmpty ?? false,
      (photoUrls.isNotEmpty || (photoUrl?.trim().isNotEmpty ?? false)),
      bio?.trim().isNotEmpty ?? false,
      validPrompts >= ProfilePromptLibrary.requiredPromptCount,
    ];
    final completeCount = checks.where((value) => value).length;
    return completeCount / checks.length;
  }

  bool get isDatingPaused => datingStatus == DatingStatus.paused;

  int displayAge({DateTime? now}) => dateOfBirth == null
      ? age
      : const AgePolicyService().ageOnDate(dateOfBirth!, now ?? DateTime.now());

  bool get hasDateOfBirth => dateOfBirth != null;

  bool get isAdult => displayAge() >= AgePolicyService.minimumDatingAge;

  bool get canUseDatingFeatures =>
      isAdult && moderationStatus == ModerationStatus.active;

  bool get isLegacyCompletedProfile =>
      datingProfileVersion == 0 && isProfileComplete;

  bool get hasCompletedRequiredOnboarding =>
      isLegacyCompletedProfile ||
      (isProfileComplete &&
          datingProfileComplete &&
          requiredCompatibilityComplete);

  bool get canReceiveNewIntroductions =>
      datingStatus == DatingStatus.active &&
      hasCompletedRequiredOnboarding &&
      canUseDatingFeatures;

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    int? age,
    String? gender,
    List<String>? interestedIn,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    String? bio,
    String? country,
    String? city,
    String? photoUrl,
    List<String>? photoUrls,
    List<ProfilePromptAnswer>? profilePrompts,
    int? datingProfileVersion,
    DatingStatus? datingStatus,
    DateTime? datingPausedAt,
    bool clearDatingPausedAt = false,
    ModerationStatus? moderationStatus,
    VerificationStatus? verificationStatus,
    Map<String, PhotoModerationStatus>? photoModerationStatuses,
    ProfileTextModerationStatus? bioModerationStatus,
    Map<String, ProfileTextModerationStatus>? promptModerationStatuses,
    bool? isProfileComplete,
    bool? datingProfileComplete,
    bool? requiredCompatibilityComplete,
    String? onboardingStep,
    bool clearOnboardingStep = false,
    String? notificationToken,
    double? latitude,
    bool clearLatitude = false,
    double? longitude,
    bool clearLongitude = false,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      interestedIn: interestedIn ?? this.interestedIn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      bio: bio ?? this.bio,
      country: country ?? this.country,
      city: city ?? this.city,
      photoUrl: photoUrl ?? this.photoUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      profilePrompts: profilePrompts ?? this.profilePrompts,
      datingProfileVersion: datingProfileVersion ?? this.datingProfileVersion,
      datingStatus: datingStatus ?? this.datingStatus,
      datingPausedAt: clearDatingPausedAt
          ? null
          : (datingPausedAt ?? this.datingPausedAt),
      moderationStatus: moderationStatus ?? this.moderationStatus,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      photoModerationStatuses:
          photoModerationStatuses ?? this.photoModerationStatuses,
      bioModerationStatus: bioModerationStatus ?? this.bioModerationStatus,
      promptModerationStatuses:
          promptModerationStatuses ?? this.promptModerationStatuses,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      datingProfileComplete:
          datingProfileComplete ?? this.datingProfileComplete,
      requiredCompatibilityComplete:
          requiredCompatibilityComplete ?? this.requiredCompatibilityComplete,
      onboardingStep: clearOnboardingStep
          ? null
          : (onboardingStep ?? this.onboardingStep),
      notificationToken: notificationToken ?? this.notificationToken,
      latitude: clearLatitude ? null : (latitude ?? this.latitude),
      longitude: clearLongitude ? null : (longitude ?? this.longitude),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'age': age,
      'gender': gender,
      'interestedIn': interestedIn,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'dateOfBirth': dateOfBirth == null
          ? null
          : Timestamp.fromDate(dateOfBirth!),
      'bio': bio,
      'country': country,
      'city': city,
      'photoUrl': photoUrl,
      'photoUrls': photoUrls,
      'profilePrompts': profilePrompts.map((prompt) => prompt.toMap()).toList(),
      'datingProfileVersion': datingProfileVersion,
      'datingStatus': datingStatus.name,
      'datingPausedAt': datingPausedAt == null
          ? null
          : Timestamp.fromDate(datingPausedAt!),
      'moderationStatus': moderationStatus.name,
      'verificationStatus': verificationStatus.name,
      'photoModerationStatuses': photoModerationStatuses.map(
        (photo, status) => MapEntry(photo, status.name),
      ),
      'bioModerationStatus': bioModerationStatus.name,
      'promptModerationStatuses': promptModerationStatuses.map(
        (promptId, status) => MapEntry(promptId, status.name),
      ),
      'isProfileComplete': isProfileComplete,
      'datingProfileComplete': datingProfileComplete,
      'requiredCompatibilityComplete': requiredCompatibilityComplete,
      'onboardingStep': onboardingStep,
      'notificationToken': notificationToken,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  Map<String, dynamic> toEditableMap() {
    final map = toMap()
      ..remove('moderationStatus')
      ..remove('verificationStatus')
      ..remove('photoModerationStatuses')
      ..remove('bioModerationStatus')
      ..remove('promptModerationStatuses');
    return map;
  }

  Map<String, dynamic> toPublicProfileMap({DateTime? now}) {
    return {
      'id': id,
      'displayName': displayName,
      'age': displayAge(now: now),
      'gender': gender,
      'country': country,
      'city': city,
      'bio': bio,
      'photoUrl': photoUrl,
      'photoUrls': photoUrls,
      'profilePrompts': profilePrompts.map((prompt) => prompt.toMap()).toList(),
      'verificationStatus': verificationStatus.name,
    };
  }

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    DateTime readDate(dynamic value, DateTime fallback) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      if (value is String) {
        return DateTime.tryParse(value) ?? fallback;
      }
      return fallback;
    }

    DateTime? readNullableDate(dynamic value) {
      if (value == null) {
        return null;
      }
      return readDate(value, DateTime.now());
    }

    double? readDouble(dynamic value) {
      if (value is num) {
        return value.toDouble();
      }
      return null;
    }

    DatingStatus readDatingStatus(dynamic value) {
      return DatingStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => DatingStatus.active,
      );
    }

    T readEnum<T extends Enum>(List<T> values, dynamic value, T fallback) {
      if (value is! String) {
        return fallback;
      }
      for (final item in values) {
        if (item.name == value) {
          return item;
        }
      }
      return fallback;
    }

    Map<String, T> readEnumMap<T extends Enum>(
      dynamic value,
      List<T> values,
      T fallback,
    ) {
      if (value is! Map) {
        return const {};
      }
      return value.map<String, T>((key, rawStatus) {
        return MapEntry(key as String, readEnum(values, rawStatus, fallback));
      });
    }

    ({double? latitude, double? longitude}) readCoordinates() {
      final directLatitude = readDouble(map['latitude'] ?? map['lat']);
      final directLongitude = readDouble(map['longitude'] ?? map['lng']);
      if (directLatitude != null && directLongitude != null) {
        return (latitude: directLatitude, longitude: directLongitude);
      }

      final location = map['location'];
      if (location is GeoPoint) {
        return (latitude: location.latitude, longitude: location.longitude);
      }
      if (location is Map) {
        return (
          latitude: readDouble(location['latitude'] ?? location['lat']),
          longitude: readDouble(location['longitude'] ?? location['lng']),
        );
      }
      return (latitude: null, longitude: null);
    }

    final savedPhotos = (map['photoUrls'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    final primaryPhoto = map['photoUrl'] as String?;
    final mergedPhotos = [
      if (primaryPhoto != null && primaryPhoto.isNotEmpty) primaryPhoto,
      ...savedPhotos.where((url) => url != primaryPhoto),
    ];
    final rawPrompts = map['profilePrompts'];
    final prompts = rawPrompts is List
        ? rawPrompts
              .whereType<Map>()
              .map(ProfilePromptAnswer.fromMap)
              .where(
                (prompt) =>
                    prompt.promptId.trim().isNotEmpty &&
                    prompt.answer.trim().isNotEmpty,
              )
              .toList()
        : const <ProfilePromptAnswer>[];
    final coordinates = readCoordinates();

    return AppUser(
      id: id,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Duolynk Member',
      age: map['age'] is num ? (map['age'] as num).round() : 18,
      gender: map['gender'] as String? ?? 'unspecified',
      interestedIn: (map['interestedIn'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      createdAt: readDate(map['createdAt'], DateTime.now()),
      updatedAt: readDate(map['updatedAt'], DateTime.now()),
      dateOfBirth: readNullableDate(map['dateOfBirth'] ?? map['dob']),
      bio: map['bio'] as String?,
      country: map['country'] as String?,
      city: map['city'] as String?,
      photoUrl: primaryPhoto,
      photoUrls: mergedPhotos,
      profilePrompts: prompts,
      datingProfileVersion: map['datingProfileVersion'] as int? ?? 0,
      datingStatus: readDatingStatus(map['datingStatus']),
      datingPausedAt: readNullableDate(map['datingPausedAt']),
      moderationStatus: readEnum(
        ModerationStatus.values,
        map['moderationStatus'],
        ModerationStatus.active,
      ),
      verificationStatus: readEnum(
        VerificationStatus.values,
        map['verificationStatus'],
        VerificationStatus.unverified,
      ),
      photoModerationStatuses: readEnumMap(
        map['photoModerationStatuses'],
        PhotoModerationStatus.values,
        PhotoModerationStatus.approved,
      ),
      bioModerationStatus: readEnum(
        ProfileTextModerationStatus.values,
        map['bioModerationStatus'],
        ProfileTextModerationStatus.approved,
      ),
      promptModerationStatuses: readEnumMap(
        map['promptModerationStatuses'],
        ProfileTextModerationStatus.values,
        ProfileTextModerationStatus.approved,
      ),
      isProfileComplete: map['isProfileComplete'] as bool? ?? false,
      datingProfileComplete:
          map['datingProfileComplete'] as bool? ??
          (map['datingProfileVersion'] == 0
              ? (map['isProfileComplete'] as bool? ?? false)
              : false),
      requiredCompatibilityComplete:
          map['requiredCompatibilityComplete'] as bool? ??
          (map['datingProfileVersion'] == 0
              ? (map['isProfileComplete'] as bool? ?? false)
              : false),
      onboardingStep: map['onboardingStep'] as String?,
      notificationToken: map['notificationToken'] as String?,
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
    );
  }
}
