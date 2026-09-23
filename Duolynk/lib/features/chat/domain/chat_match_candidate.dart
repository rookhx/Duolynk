import '../../../models/app_user.dart';
import '../../../models/match_model.dart';

class ChatMatchCandidate {
  const ChatMatchCandidate({required this.match, required this.partner});

  final MatchModel match;
  final AppUser partner;
}
