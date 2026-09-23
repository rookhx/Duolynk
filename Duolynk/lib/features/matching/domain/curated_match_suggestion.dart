import '../../../models/app_user.dart';
import '../../../models/match_model.dart';

class CuratedMatchSuggestion {
  const CuratedMatchSuggestion({
    required this.match,
    required this.partner,
    this.publicInterests = const [],
    this.relationshipIntention = '',
    this.hasProfileUnlock = false,
  });

  final MatchModel match;
  final AppUser partner;
  final List<String> publicInterests;
  final String relationshipIntention;
  final bool hasProfileUnlock;
}
