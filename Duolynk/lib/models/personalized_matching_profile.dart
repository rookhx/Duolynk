import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalizedMatchingSettings {
  const PersonalizedMatchingSettings({this.enabled = false});

  final bool enabled;

  Map<String, dynamic> toMap() => {'enabled': enabled};

  static PersonalizedMatchingSettings fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const PersonalizedMatchingSettings();
    }
    return PersonalizedMatchingSettings(enabled: map['enabled'] == true);
  }
}

class PersonalizedMatchingProfile {
  const PersonalizedMatchingProfile({
    required this.userId,
    required this.enabled,
    required this.feedbackSignalCount,
    required this.categoryWeightAdjustments,
    this.updatedAt,
  });

  final String userId;
  final bool enabled;
  final int feedbackSignalCount;
  final Map<String, double> categoryWeightAdjustments;
  final DateTime? updatedAt;

  bool get hasEnoughSignals => feedbackSignalCount >= 3;

  bool get canPersonalize => enabled && hasEnoughSignals;

  factory PersonalizedMatchingProfile.baseline(
    String userId, {
    bool enabled = false,
  }) {
    return PersonalizedMatchingProfile(
      userId: userId,
      enabled: enabled,
      feedbackSignalCount: 0,
      categoryWeightAdjustments: const {},
    );
  }

  PersonalizedMatchingProfile copyWith({
    String? userId,
    bool? enabled,
    int? feedbackSignalCount,
    Map<String, double>? categoryWeightAdjustments,
    DateTime? updatedAt,
  }) {
    return PersonalizedMatchingProfile(
      userId: userId ?? this.userId,
      enabled: enabled ?? this.enabled,
      feedbackSignalCount: feedbackSignalCount ?? this.feedbackSignalCount,
      categoryWeightAdjustments:
          categoryWeightAdjustments ?? this.categoryWeightAdjustments,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'enabled': enabled,
      'feedbackSignalCount': feedbackSignalCount,
      'categoryWeightAdjustments': categoryWeightAdjustments,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  static PersonalizedMatchingProfile fromMap(
    String userId,
    Map<String, dynamic>? map,
  ) {
    if (map == null) {
      return PersonalizedMatchingProfile.baseline(userId);
    }
    return PersonalizedMatchingProfile(
      userId: (map['userId'] as String?) ?? userId,
      enabled: map['enabled'] == true,
      feedbackSignalCount: _readInt(map['feedbackSignalCount']) ?? 0,
      categoryWeightAdjustments: _readDoubleMap(
        map['categoryWeightAdjustments'],
      ),
      updatedAt: _readDate(map['updatedAt']),
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return null;
  }

  static Map<String, double> _readDoubleMap(dynamic value) {
    if (value is! Map) {
      return const {};
    }
    final result = <String, double>{};
    value.forEach((key, raw) {
      if (key is String && raw is num) {
        result[key] = raw.toDouble();
      }
    });
    return result;
  }
}
