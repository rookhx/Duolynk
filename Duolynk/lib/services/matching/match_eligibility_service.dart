import 'dart:math' as math;

import '../../core/config/country_regions.dart';
import '../../models/app_user.dart';
import '../../models/compatibility_profile.dart';

enum MatchEligibilityRejectionCode {
  sameUser,
  blockedUser,
  blockedByUser,
  deletedAccount,
  inactiveAccount,
  matchingDisabled,
  onboardingIncomplete,
  underageAccount,
  moderationRestricted,
  existingMatch,
  recentlyRecommended,
  genderPreferenceMismatch,
  agePreferenceMismatch,
  distancePreferenceMismatch,
  dealBreakerConflict,
  relationshipIntentionMismatch,
}

class MatchEligibilityResult {
  const MatchEligibilityResult._({required this.eligible, this.rejectionCode});

  const MatchEligibilityResult.eligible() : this._(eligible: true);

  const MatchEligibilityResult.rejected(
    MatchEligibilityRejectionCode rejectionCode,
  ) : this._(eligible: false, rejectionCode: rejectionCode);

  final bool eligible;
  final MatchEligibilityRejectionCode? rejectionCode;
}

class MatchEligibilityContext {
  const MatchEligibilityContext({
    this.blockedUserIds = const {},
    this.blockedByUserIds = const {},
    this.activePartnerIds = const {},
    this.historicalPairKeys = const {},
    this.candidateAccountData = const {},
  });

  final Set<String> blockedUserIds;
  final Set<String> blockedByUserIds;
  final Set<String> activePartnerIds;
  final Set<String> historicalPairKeys;
  final Map<String, dynamic> candidateAccountData;
}

class MatchEligibilityService {
  const MatchEligibilityService();

  MatchEligibilityResult evaluate({
    required CompatibilityProfile currentUser,
    required CompatibilityProfile candidate,
    MatchEligibilityContext context = const MatchEligibilityContext(),
  }) {
    final currentUserId = currentUser.user.id;
    final candidateUserId = candidate.user.id;

    if (currentUserId == candidateUserId) {
      return const MatchEligibilityResult.rejected(
        MatchEligibilityRejectionCode.sameUser,
      );
    }
    if (context.blockedUserIds.contains(candidateUserId)) {
      return const MatchEligibilityResult.rejected(
        MatchEligibilityRejectionCode.blockedUser,
      );
    }
    if (context.blockedByUserIds.contains(candidateUserId)) {
      return const MatchEligibilityResult.rejected(
        MatchEligibilityRejectionCode.blockedByUser,
      );
    }
    if (_isDeleted(context.candidateAccountData)) {
      return const MatchEligibilityResult.rejected(
        MatchEligibilityRejectionCode.deletedAccount,
      );
    }
    if (_isInactive(context.candidateAccountData)) {
      return const MatchEligibilityResult.rejected(
        MatchEligibilityRejectionCode.inactiveAccount,
      );
    }
    if (currentUser.user.isDatingPaused || candidate.user.isDatingPaused) {
      return const MatchEligibilityResult.rejected(
        MatchEligibilityRejectionCode.matchingDisabled,
      );
    }
    if (!currentUser.user.isAdult || !candidate.user.isAdult) {
      return const MatchEligibilityResult.rejected(
        MatchEligibilityRejectionCode.underageAccount,
      );
    }
    if (currentUser.user.moderationStatus != ModerationStatus.active ||
        candidate.user.moderationStatus != ModerationStatus.active) {
      return const MatchEligibilityResult.rejected(
        MatchEligibilityRejectionCode.moderationRestricted,
      );
    }
    if (!currentUser.user.hasCompletedRequiredOnboarding ||
        !candidate.user.hasCompletedRequiredOnboarding) {
      return const MatchEligibilityResult.rejected(
        MatchEligibilityRejectionCode.onboardingIncomplete,
      );
    }
    if (_isMatchingDisabled(context.candidateAccountData)) {
      return const MatchEligibilityResult.rejected(
        MatchEligibilityRejectionCode.matchingDisabled,
      );
    }
    if (context.activePartnerIds.contains(candidateUserId)) {
      return const MatchEligibilityResult.rejected(
        MatchEligibilityRejectionCode.existingMatch,
      );
    }
    if (context.historicalPairKeys.contains(
      _pairKey(currentUserId, candidateUserId),
    )) {
      return const MatchEligibilityResult.rejected(
        MatchEligibilityRejectionCode.recentlyRecommended,
      );
    }
    if (!_mutuallyGenderCompatible(currentUser, candidate)) {
      return const MatchEligibilityResult.rejected(
        MatchEligibilityRejectionCode.genderPreferenceMismatch,
      );
    }
    if (!_mutuallyAgeCompatible(currentUser, candidate)) {
      return const MatchEligibilityResult.rejected(
        MatchEligibilityRejectionCode.agePreferenceMismatch,
      );
    }
    if (!_mutuallyDistanceCompatible(currentUser, candidate)) {
      return const MatchEligibilityResult.rejected(
        MatchEligibilityRejectionCode.distancePreferenceMismatch,
      );
    }
    if (_hasDealBreakerConflict(currentUser, candidate) ||
        _hasDealBreakerConflict(candidate, currentUser)) {
      return const MatchEligibilityResult.rejected(
        MatchEligibilityRejectionCode.dealBreakerConflict,
      );
    }
    if (!_relationshipIntentionsCompatible(currentUser, candidate)) {
      return const MatchEligibilityResult.rejected(
        MatchEligibilityRejectionCode.relationshipIntentionMismatch,
      );
    }

    return const MatchEligibilityResult.eligible();
  }

  bool _mutuallyGenderCompatible(
    CompatibilityProfile currentUser,
    CompatibilityProfile candidate,
  ) {
    return _interestsIncludeGender(
          currentUser.user.interestedIn,
          candidate.user.gender,
        ) &&
        _interestsIncludeGender(
          candidate.user.interestedIn,
          currentUser.user.gender,
        );
  }

  bool _interestsIncludeGender(List<String> interests, String gender) {
    final normalizedGender = _normalize(gender);
    if (normalizedGender == null || normalizedGender == 'unspecified') {
      // Legacy or undisclosed gender cannot be evaluated reliably. Do not
      // reject solely on this missing value; explicit usable settings still
      // become hard filters as soon as both profiles have them.
      return true;
    }
    if (interests.isEmpty) {
      return true;
    }

    final normalizedInterests = interests.map(_normalize).whereType<String>();
    if (normalizedInterests.contains('everyone')) {
      return true;
    }

    final acceptedLabels = switch (normalizedGender) {
      'woman' => const {'women', 'woman'},
      'man' => const {'men', 'man'},
      'non-binary' || 'nonbinary' => const {
        'non-binary people',
        'nonbinary people',
        'non-binary',
        'nonbinary',
      },
      'prefer not to say' => const {'everyone'},
      _ => {normalizedGender},
    };

    return normalizedInterests.any(acceptedLabels.contains);
  }

  bool _mutuallyAgeCompatible(
    CompatibilityProfile currentUser,
    CompatibilityProfile candidate,
  ) {
    return _ageAllowedByPreference(
          candidate.user.displayAge(),
          currentUser.preferenceAnswers['ageRange'],
        ) &&
        _ageAllowedByPreference(
          currentUser.user.displayAge(),
          candidate.preferenceAnswers['ageRange'],
        );
  }

  bool _ageAllowedByPreference(int age, dynamic ageRange) {
    final range = _parseAgeRange(ageRange);
    if (range == null) {
      return true;
    }
    if (age < range.min) {
      return false;
    }
    return range.max == null || age <= range.max!;
  }

  _AgeRange? _parseAgeRange(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.endsWith('+')) {
      final min = int.tryParse(normalized.substring(0, normalized.length - 1));
      return min == null ? null : _AgeRange(min: min);
    }
    final parts = normalized.split('-');
    if (parts.length != 2) {
      return null;
    }
    final min = int.tryParse(parts[0].trim());
    final max = int.tryParse(parts[1].trim());
    if (min == null || max == null) {
      return null;
    }
    return _AgeRange(min: min, max: max);
  }

  bool _mutuallyDistanceCompatible(
    CompatibilityProfile currentUser,
    CompatibilityProfile candidate,
  ) {
    return _distanceAllowedByPreference(
          currentUser,
          candidate,
          currentUser.preferenceAnswers['distancePreference'],
        ) &&
        _distanceAllowedByPreference(
          candidate,
          currentUser,
          candidate.preferenceAnswers['distancePreference'],
        );
  }

  bool _distanceAllowedByPreference(
    CompatibilityProfile owner,
    CompatibilityProfile other,
    dynamic preference,
  ) {
    final normalizedPreference = _normalize(
      preference is String ? preference : null,
    );
    if (normalizedPreference == null || normalizedPreference == 'worldwide') {
      return true;
    }

    final ownerCountry = _normalize(owner.user.country);
    final otherCountry = _normalize(other.user.country);
    final ownerCity = _normalize(owner.user.city);
    final otherCity = _normalize(other.user.city);

    if (owner.user.latitude != null &&
        owner.user.longitude != null &&
        other.user.latitude != null &&
        other.user.longitude != null) {
      final distanceKm = _haversineKm(
        owner.user.latitude!,
        owner.user.longitude!,
        other.user.latitude!,
        other.user.longitude!,
      );
      if (normalizedPreference == 'same city') {
        return distanceKm <= 50;
      }
      if (normalizedPreference == 'same country') {
        return ownerCountry == null ||
            otherCountry == null ||
            ownerCountry == otherCountry;
      }
      if (normalizedPreference == 'europe') {
        return CountryRegions.regionFor(owner.user.country) == 'Europe' &&
            CountryRegions.regionFor(other.user.country) == 'Europe';
      }
    }

    // Older profiles may only have city/country text and no reliable
    // coordinates. Enforce the stored geographic preference when the required
    // fields exist; otherwise allow the candidate through so legacy profiles do
    // not disappear from matching just because location data is incomplete.
    if (normalizedPreference == 'same city') {
      if (ownerCountry == null ||
          otherCountry == null ||
          ownerCity == null ||
          otherCity == null) {
        return true;
      }
      return ownerCountry == otherCountry && ownerCity == otherCity;
    }
    if (normalizedPreference == 'same country') {
      if (ownerCountry == null || otherCountry == null) {
        return true;
      }
      return ownerCountry == otherCountry;
    }
    if (normalizedPreference == 'europe') {
      final ownerRegion = CountryRegions.regionFor(owner.user.country);
      final otherRegion = CountryRegions.regionFor(other.user.country);
      if (ownerRegion == null || otherRegion == null) {
        return true;
      }
      return ownerRegion == 'Europe' && otherRegion == 'Europe';
    }
    return true;
  }

  bool _hasDealBreakerConflict(
    CompatibilityProfile owner,
    CompatibilityProfile other,
  ) {
    final dealBreakers = _stringList(
      owner.preferenceAnswers['dealBreakers'],
    ).map(_normalize).whereType<String>().toSet();
    if (dealBreakers.isEmpty) {
      return false;
    }

    final otherLifestyle = other.lifestyleAnswers.map(
      (key, value) => MapEntry(key, _normalize(value) ?? ''),
    );
    final otherGoals = other.relationshipGoalAnswers.map(
      (key, value) => MapEntry(key, _normalize(value) ?? ''),
    );

    if (dealBreakers.contains('smoking') &&
        {
          'occasionally',
          'socially',
          'regularly',
        }.contains(otherLifestyle['smoking'])) {
      return true;
    }
    if (dealBreakers.contains('heavy drinking') &&
        otherLifestyle['drinking'] == 'often') {
      return true;
    }
    if (dealBreakers.contains('not wanting commitment') &&
        (otherGoals['longTermRelationship'] == 'not looking for that' ||
            otherGoals['casualDating'] == 'prefer casual right now')) {
      return true;
    }
    if (dealBreakers.contains('different family values') &&
        otherGoals['familyImportance'] == 'less important') {
      return true;
    }
    if (dealBreakers.contains('no interest in children') &&
        otherGoals['children'] == 'do not want children') {
      return true;
    }
    return false;
  }

  bool _relationshipIntentionsCompatible(
    CompatibilityProfile currentUser,
    CompatibilityProfile candidate,
  ) {
    final currentIntent = _relationshipIntent(
      currentUser.relationshipGoalAnswers,
    );
    final candidateIntent = _relationshipIntent(
      candidate.relationshipGoalAnswers,
    );
    if (currentIntent == null || candidateIntent == null) {
      return true;
    }
    return _compatibleIntentions[currentIntent]!.contains(candidateIntent);
  }

  _RelationshipIntent? _relationshipIntent(Map<String, String> answers) {
    final marriage = _normalize(answers['marriage']);
    final longTerm = _normalize(answers['longTermRelationship']);
    final casual = _normalize(answers['casualDating']);

    if (marriage == 'definitely want it' ||
        longTerm == 'essential' ||
        longTerm == 'very important') {
      return _RelationshipIntent.committed;
    }
    if (marriage == 'do not want it' &&
        longTerm == 'not looking for that' &&
        (casual == 'comfortable with it' ||
            casual == 'prefer casual right now')) {
      return _RelationshipIntent.casualOnly;
    }
    if (longTerm == 'not looking for that' &&
        casual == 'prefer casual right now') {
      return _RelationshipIntent.casualOnly;
    }
    if (longTerm == 'open to it' ||
        longTerm == 'not sure yet' ||
        casual == 'depends on the person' ||
        casual == 'open in the short term' ||
        marriage == 'open to it' ||
        marriage == 'unsure' ||
        marriage == 'not a priority') {
      return _RelationshipIntent.flexible;
    }
    return null;
  }

  bool _isDeleted(Map<String, dynamic> data) {
    return data['deletedAt'] != null || data['isDeleted'] == true;
  }

  bool _isInactive(Map<String, dynamic> data) {
    return data['isDisabled'] == true ||
        data['disabled'] == true ||
        data['accountDisabled'] == true ||
        data['isActive'] == false;
  }

  bool _isMatchingDisabled(Map<String, dynamic> data) {
    return data['participatesInMatching'] == false ||
        data['matchingEnabled'] == false ||
        data['matchingDisabled'] == true ||
        data['datingStatus'] == 'paused' ||
        data['moderationStatus'] == ModerationStatus.underReview.name ||
        data['moderationStatus'] == ModerationStatus.suspended.name ||
        data['moderationStatus'] == ModerationStatus.banned.name;
  }

  List<String> _stringList(dynamic value) {
    return (value as List<dynamic>? ?? const []).whereType<String>().toList();
  }

  double _haversineKm(
    double firstLatitude,
    double firstLongitude,
    double secondLatitude,
    double secondLongitude,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _radians(secondLatitude - firstLatitude);
    final dLon = _radians(secondLongitude - firstLongitude);
    final lat1 = _radians(firstLatitude);
    final lat2 = _radians(secondLatitude);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  String _pairKey(String first, String second) {
    final sorted = [first, second]..sort();
    return '${sorted.first}_${sorted.last}';
  }

  String? _normalize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim().toLowerCase();
  }
}

class _AgeRange {
  const _AgeRange({required this.min, this.max});

  final int min;
  final int? max;
}

enum _RelationshipIntent { committed, flexible, casualOnly }

const _compatibleIntentions = {
  _RelationshipIntent.committed: {
    _RelationshipIntent.committed,
    _RelationshipIntent.flexible,
  },
  _RelationshipIntent.flexible: {
    _RelationshipIntent.committed,
    _RelationshipIntent.flexible,
    _RelationshipIntent.casualOnly,
  },
  _RelationshipIntent.casualOnly: {
    _RelationshipIntent.flexible,
    _RelationshipIntent.casualOnly,
  },
};
