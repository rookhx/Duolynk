import 'chat_match_candidate.dart';
import '../../../models/chat_model.dart';

class ChatThreadState {
  const ChatThreadState({
    this.threads = const [],
    this.availableMatches = const [],
    this.isLoading = false,
  });

  final List<ChatModel> threads;
  final List<ChatMatchCandidate> availableMatches;
  final bool isLoading;
}
