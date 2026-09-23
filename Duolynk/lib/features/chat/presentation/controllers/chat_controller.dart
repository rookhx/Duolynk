import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../matching/data/matching_repository.dart';
import '../../data/chat_repository.dart';
import '../../domain/chat_match_candidate.dart';
import '../../../../models/chat_model.dart';
import '../../../../models/match_model.dart';

final chatImagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

final chatThreadsProvider = StreamProvider<List<ChatModel>>(
  (ref) => ref.watch(chatRepositoryProvider).watchChats(),
);

final chatMatchedCandidatesProvider = StreamProvider<List<ChatMatchCandidate>>(
  (ref) => ref.watch(chatRepositoryProvider).watchMatchedCandidates(),
);

final activeMatchesProvider = StreamProvider<List<MatchModel>>(
  (ref) => ref.watch(matchingRepositoryProvider).watchActiveMatches(),
);

final chatConversationProvider = StreamProvider.family<ChatModel?, String>(
  (ref, chatId) => ref.watch(chatRepositoryProvider).watchConversation(chatId),
);

final chatMessagesProvider =
    StreamProvider.family<List<ChatMessageModel>, String>(
      (ref, chatId) => ref.watch(chatRepositoryProvider).watchMessages(chatId),
    );
