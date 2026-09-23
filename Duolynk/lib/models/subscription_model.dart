import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionTier { free, premium, concierge }

enum SubscriptionPlatform { revenueCat, apple, google, web, unknown }

class SubscriptionModel {
  const SubscriptionModel({
    required this.id,
    required this.userId,
    required this.tier,
    required this.platform,
    required this.isActive,
    required this.createdAt,
    this.entitlementId,
    this.expiresAt,
    this.productId,
  });

  final String id;
  final String userId;
  final SubscriptionTier tier;
  final SubscriptionPlatform platform;
  final bool isActive;
  final DateTime createdAt;
  final String? entitlementId;
  final DateTime? expiresAt;
  final String? productId;

  bool get hasPremiumAccess =>
      isActive &&
      (tier == SubscriptionTier.premium || tier == SubscriptionTier.concierge);

  int get weeklyCandidateLimit => 10;

  int get weeklyProfileUnlockLimit => hasPremiumAccess ? 1 << 30 : 1;

  int get weeklyConversationActivationLimit => hasPremiumAccess ? 3 : 1;

  bool get canViewAllAuthorizedCandidateProfiles => hasPremiumAccess;

  int get weeklyMatchQuota => weeklyConversationActivationLimit;

  bool get hasDetailedCompatibilityReport => false;

  bool get hasPriorityMatching => false;

  String get tierLabel {
    switch (tier) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.premium:
        return 'Premium';
      case SubscriptionTier.concierge:
        return 'Concierge';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'tier': tier.name,
      'platform': platform.name,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'entitlementId': entitlementId,
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt!),
      'productId': productId,
    };
  }

  factory SubscriptionModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime readDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return DateTime.now();
    }

    DateTime? readNullableDate(dynamic value) {
      if (value == null) {
        return null;
      }
      return readDate(value);
    }

    return SubscriptionModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      tier: SubscriptionTier.values.firstWhere(
        (tier) => tier.name == map['tier'],
        orElse: () => SubscriptionTier.free,
      ),
      platform: SubscriptionPlatform.values.firstWhere(
        (platform) => platform.name == map['platform'],
        orElse: () => SubscriptionPlatform.unknown,
      ),
      isActive: map['isActive'] as bool? ?? false,
      createdAt: readDate(map['createdAt']),
      entitlementId: map['entitlementId'] as String?,
      expiresAt: readNullableDate(map['expiresAt']),
      productId: map['productId'] as String?,
    );
  }
}
