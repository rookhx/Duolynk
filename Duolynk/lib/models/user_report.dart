import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportCategory {
  fakeProfile,
  scam,
  harassment,
  sexualContent,
  hate,
  underageConcern,
  dangerousBehavior,
  spam,
  stolenPhotos,
  other,
}

enum ReportStatus { submitted, underReview, resolved, dismissed }

class UserReport {
  const UserReport({
    required this.id,
    required this.reporterUserId,
    required this.targetUserId,
    required this.category,
    required this.createdAt,
    required this.source,
    this.details,
    this.matchId,
    this.pairKey,
    this.status = ReportStatus.submitted,
  });

  static const detailsCharacterLimit = 500;

  final String id;
  final String reporterUserId;
  final String targetUserId;
  final ReportCategory category;
  final String? details;
  final DateTime createdAt;
  final String source;
  final String? matchId;
  final String? pairKey;
  final ReportStatus status;

  bool get isHighPriority => category == ReportCategory.underageConcern;

  Map<String, dynamic> toMap() {
    final normalizedDetails = _normalizeDetails(details);
    return {
      'reporterUserId': reporterUserId,
      'targetUserId': targetUserId,
      'category': category.name,
      'reason': labelFor(category),
      'details': normalizedDetails,
      'createdAt': Timestamp.fromDate(createdAt),
      'source': source,
      'matchId': matchId,
      'pairKey': pairKey,
      'status': status.name,
      'priority': isHighPriority ? 'high' : 'normal',
    };
  }

  factory UserReport.fromMap(String id, Map<String, dynamic> map) {
    DateTime readDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return DateTime.now();
    }

    return UserReport(
      id: id,
      reporterUserId: map['reporterUserId'] as String? ?? '',
      targetUserId: map['targetUserId'] as String? ?? '',
      category: _readCategory(map['category'] ?? map['reason']),
      details: _normalizeDetails(map['details'] as String?),
      createdAt: readDate(map['createdAt']),
      source: map['source'] as String? ?? '',
      matchId: map['matchId'] as String?,
      pairKey: map['pairKey'] as String?,
      status: _readStatus(map['status']),
    );
  }

  static String labelFor(ReportCategory category) {
    return switch (category) {
      ReportCategory.fakeProfile => 'Fake profile / impersonation',
      ReportCategory.scam => 'Scam / asking for money',
      ReportCategory.harassment => 'Harassment or abusive behavior',
      ReportCategory.sexualContent => 'Sexual/inappropriate content',
      ReportCategory.hate => 'Hate/discrimination',
      ReportCategory.underageConcern => 'Underage concern',
      ReportCategory.dangerousBehavior => 'Threatening or dangerous behavior',
      ReportCategory.spam => 'Spam',
      ReportCategory.stolenPhotos => 'Stolen photos',
      ReportCategory.other => 'Other',
    };
  }

  static String? _normalizeDetails(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length <= detailsCharacterLimit) {
      return trimmed;
    }
    return trimmed.substring(0, detailsCharacterLimit);
  }

  static ReportCategory _readCategory(dynamic value) {
    if (value is String) {
      for (final category in ReportCategory.values) {
        if (category.name == value) {
          return category;
        }
      }
      final normalized = value.toLowerCase();
      if (normalized.contains('fake')) return ReportCategory.fakeProfile;
      if (normalized.contains('scam')) return ReportCategory.scam;
      if (normalized.contains('harass') || normalized.contains('abuse')) {
        return ReportCategory.harassment;
      }
      if (normalized.contains('spam')) return ReportCategory.spam;
    }
    return ReportCategory.other;
  }

  static ReportStatus _readStatus(dynamic value) {
    if (value is String) {
      for (final status in ReportStatus.values) {
        if (status.name == value) {
          return status;
        }
      }
    }
    return ReportStatus.submitted;
  }
}
