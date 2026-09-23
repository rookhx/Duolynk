import 'app_user.dart';
import 'compatibility_insight.dart';
import 'match_model.dart';

class CuratedCandidateTeaser {
  const CuratedCandidateTeaser({
    required this.matchId,
    required this.candidateUserId,
    required this.compatibilityScore,
    required this.generalLocation,
    required this.relationshipIntention,
    required this.isVerified,
    required this.teaserInsights,
    this.match,
  });

  final String matchId;
  final String candidateUserId;
  final int compatibilityScore;
  final String? generalLocation;
  final String? relationshipIntention;
  final bool isVerified;
  final List<CompatibilityInsight> teaserInsights;
  final MatchModel? match;

  factory CuratedCandidateTeaser.fromMatch({
    required MatchModel match,
    required AppUser candidate,
    String? relationshipIntention,
  }) {
    final locationParts = [
      if ((candidate.city ?? '').trim().isNotEmpty) candidate.city!.trim(),
      if ((candidate.country ?? '').trim().isNotEmpty)
        candidate.country!.trim(),
    ];
    return CuratedCandidateTeaser(
      matchId: match.id,
      candidateUserId: candidate.id,
      compatibilityScore: match.compatibilityScore,
      generalLocation: locationParts.isEmpty ? null : locationParts.join(', '),
      relationshipIntention: relationshipIntention,
      isVerified: candidate.verificationStatus == VerificationStatus.verified,
      teaserInsights: match.compatibilityReasons.take(2).toList(),
      match: match,
    );
  }
}
