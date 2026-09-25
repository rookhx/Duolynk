import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/config/firestore_paths.dart';
import '../../../core/config/storage_paths.dart';
import '../../../core/demo/demo_store.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/app_user.dart';
import '../../../models/chat_model.dart';
import '../../../models/match_model.dart';
import '../../../services/access/trusted_access_repository.dart';
import '../../../services/analytics/analytics_event_service.dart';
import '../../../services/firebase/firebase_auth_service.dart';
import '../../../services/firebase/firebase_storage_service.dart';
import '../../../services/firebase/firestore_service.dart';
import '../domain/chat_match_candidate.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(
    firestoreService: ref.watch(firestoreServiceProvider),
    authService: ref.watch(firebaseAuthServiceProvider),
    storageService: ref.watch(firebaseStorageServiceProvider),
    trustedAccessRepository: ref.watch(trustedAccessRepositoryProvider),
  ),
);

class ChatRepository {
  const ChatRepository({
    required FirestoreService firestoreService,
    required FirebaseAuthService authService,
    required FirebaseStorageService storageService,
    required TrustedAccessRepository trustedAccessRepository,
  }) : _firestoreService = firestoreService,
       _authService = authService,
       _storageService = storageService,
       _trustedAccessRepository = trustedAccessRepository;

  final FirestoreService _firestoreService;
  final FirebaseAuthService _authService;
  final FirebaseStorageService _storageService;
  final TrustedAccessRepository _trustedAccessRepository;

  Future<List<ChatModel>> fetchChats() async {
    if (!AppEnvironment.firebaseEnabled) {
      return DemoStore.blockedUserIds.contains(DemoStore.activeMatch.partnerId)
          ? const []
          : [DemoStore.chat];
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return const [];
    }

    final snapshot = await _firestoreService
        .collection(FirestorePaths.conversations)
        .where('memberIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .get();

    final chats = <ChatModel>[];
    for (final doc in snapshot.docs) {
      final conversation = ChatModel.fromMap(doc.id, doc.data());
      if (!await _conversationStillAvailable(conversation)) {
        continue;
      }
      final hasConversationAccess = await _hasConversationActivation(
        userId: userId,
        conversation: conversation,
      );
      chats.add(
        _sanitizeConversation(conversation, userId, hasConversationAccess),
      );
    }
    return chats;
  }

  Stream<List<ChatModel>> watchChats() {
    if (!AppEnvironment.firebaseEnabled) {
      final chats =
          DemoStore.blockedUserIds.contains(DemoStore.activeMatch.partnerId)
          ? const <ChatModel>[]
          : [DemoStore.chat];
      return Stream.value(chats);
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return const Stream<List<ChatModel>>.empty();
    }

    return _firestoreService
        .collection(FirestorePaths.conversations)
        .where('memberIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final chats = <ChatModel>[];
          for (final doc in snapshot.docs) {
            final conversation = ChatModel.fromMap(doc.id, doc.data());
            if (!await _conversationStillAvailable(conversation)) {
              continue;
            }
            final hasConversationAccess = await _hasConversationActivation(
              userId: userId,
              conversation: conversation,
            );
            chats.add(
              _sanitizeConversation(
                conversation,
                userId,
                hasConversationAccess,
              ),
            );
          }
          return chats;
        });
  }

  Stream<List<ChatMatchCandidate>> watchMatchedCandidates() {
    if (!AppEnvironment.firebaseEnabled) {
      if (DemoStore.blockedUserIds.contains(DemoStore.activeMatch.partnerId)) {
        return Stream.value(const <ChatMatchCandidate>[]);
      }
      return Stream.value([
        ChatMatchCandidate(
          match: DemoStore.activeMatch,
          partner: DemoStore.weeklyMatch.profile.user,
        ),
      ]);
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return const Stream<List<ChatMatchCandidate>>.empty();
    }

    // Rules only allow reading matches that list the user in participantIds,
    // so an unfiltered listener on `matches` is rejected.
    return _firestoreService
        .collection(FirestorePaths.matches)
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .asyncMap((snapshot) async {
          final candidates = <ChatMatchCandidate>[];
          for (final doc in snapshot.docs) {
            final match = MatchModel.fromMap(doc.id, doc.data());
            final isAvailable =
                (match.isLegacyActiveMatch &&
                    match.userId == userId &&
                    match.status == MatchStatus.active) ||
                match.isConversationEligible;
            if (!isAvailable) {
              continue;
            }
            final AuthorizedProfile partner;
            try {
              partner = await _trustedAccessRepository.fetchAuthorizedProfile(
                candidateUid: match.partnerIdFor(userId),
              );
            } catch (error) {
              debugPrint('Could not load chat partner for ${match.id}: $error');
              continue;
            }
            candidates.add(
              ChatMatchCandidate(match: match, partner: partner.user),
            );
          }
          return candidates;
        });
  }

  Stream<ChatModel?> watchConversation(String chatId) {
    if (!AppEnvironment.firebaseEnabled) {
      return Stream.value(chatId == DemoStore.chat.id ? DemoStore.chat : null);
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return const Stream<ChatModel?>.empty();
    }

    return _firestoreService
        .watchDocument(FirestorePaths.conversation(chatId))
        .asyncMap((snapshot) async {
          final data = snapshot.data();
          if (data == null) {
            return null;
          }

          final conversation = ChatModel.fromMap(snapshot.id, data);
          if (!conversation.memberIds.contains(userId)) {
            return null;
          }
          if (!await _conversationStillAvailable(conversation)) {
            return null;
          }

          final hasConversationAccess = await _hasConversationActivation(
            userId: userId,
            conversation: conversation,
          );
          return _sanitizeConversation(
            conversation,
            userId,
            hasConversationAccess,
          );
        });
  }

  Stream<List<ChatMessageModel>> watchMessages(String chatId) {
    if (!AppEnvironment.firebaseEnabled) {
      return Stream.value(
        chatId == DemoStore.chat.id ? DemoStore.messages : const [],
      );
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return const Stream<List<ChatMessageModel>>.empty();
    }

    return Stream.fromFuture(
      _fetchConversation(chatId).then((conversation) async {
        if (conversation == null) {
          return false;
        }
        return _hasConversationActivation(
          userId: userId,
          conversation: conversation,
        );
      }),
    ).asyncExpand((hasConversationAccess) {
      final query = _firestoreService
          .collection(FirestorePaths.conversationMessages(chatId))
          .orderBy('createdAt');
      final scopedQuery = hasConversationAccess
          ? query
          : query.where('senderId', isEqualTo: userId);

      return scopedQuery.snapshots().asyncMap((snapshot) async {
        final conversation = await _fetchConversation(chatId);
        if (conversation == null ||
            !await _conversationStillAvailable(conversation)) {
          return const <ChatMessageModel>[];
        }
        return snapshot.docs
            .map((doc) => ChatMessageModel.fromMap(doc.id, doc.data()))
            .map(
              (message) =>
                  _sanitizeMessage(message, userId, hasConversationAccess),
            )
            .toList();
      });
    });
  }

  Future<String> ensureConversationForMatch(MatchModel match) async {
    if (!AppEnvironment.firebaseEnabled) {
      return DemoStore.chat.id;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      throw StateError('A signed-in user is required to start a conversation.');
    }
    if (!match.isConversationEligible ||
        !(match.participantIds.contains(userId) || match.userId == userId)) {
      throw StateError('Only mutual matches can open a conversation.');
    }
    if (match.chatId != null && match.chatId!.isNotEmpty) {
      return match.chatId!;
    }

    final conversationId = await _trustedAccessRepository
        .ensureConversationForMatch(matchId: match.id);
    if (conversationId.isEmpty) {
      throw StateError('Conversation could not be prepared.');
    }
    return conversationId;
  }

  Future<void> sendTextMessage({
    required String chatId,
    required String text,
  }) async {
    if (!AppEnvironment.firebaseEnabled) {
      DemoStore.addMessage(
        ChatMessageModel(
          id: 'demo_message_${DemoStore.messages.length + 1}',
          chatId: chatId,
          senderId: DemoStore.user.id,
          text: text.trim(),
          type: ChatMessageType.text,
          createdAt: DateTime.now(),
          readByUserIds: [DemoStore.user.id],
        ),
      );
      return;
    }

    final normalized = text.trim();
    if (normalized.isEmpty) {
      return;
    }

    await _sendMessage(
      chatId: chatId,
      text: normalized,
      type: ChatMessageType.text,
    );
  }

  Future<void> sendImageMessage({
    required String chatId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!AppEnvironment.firebaseEnabled) {
      DemoStore.addMessage(
        ChatMessageModel(
          id: 'demo_message_${DemoStore.messages.length + 1}',
          chatId: chatId,
          senderId: DemoStore.user.id,
          text: 'Shared a photo',
          type: ChatMessageType.image,
          createdAt: DateTime.now(),
          readByUserIds: [DemoStore.user.id],
          imageUrl: 'demo-image',
        ),
      );
      return;
    }

    final messageRef = _firestoreService
        .collection(FirestorePaths.conversationMessages(chatId))
        .doc();

    final imageUrl = await _storageService.uploadData(
      path: StoragePaths.chatAttachment(chatId, messageRef.id, fileName),
      data: bytes,
      metadata: SettableMetadata(contentType: 'image/jpeg'),
    );

    await _sendMessage(
      chatId: chatId,
      text: 'Shared a photo',
      type: ChatMessageType.image,
      imageUrl: imageUrl,
      messageIdOverride: messageRef.id,
    );
  }

  Future<void> markConversationRead(String chatId) async {
    if (!AppEnvironment.firebaseEnabled) {
      return;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return;
    }

    final conversation = await _fetchConversation(chatId);
    if (conversation == null || !conversation.memberIds.contains(userId)) {
      return;
    }

    // Messages are immutable under firestore.rules, so read state lives only
    // in the conversation's lastReadAtByUser map. update() (not set+merge)
    // makes the dotted key a nested path, and the rules require server time.
    await _firestoreService.updateDocument(FirestorePaths.conversation(chatId), {
      'lastReadAtByUser.$userId': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setTyping(String chatId, {required bool isTyping}) async {
    if (!AppEnvironment.firebaseEnabled) {
      return;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      return;
    }

    // firestore.rules require updatedAt == request.time, i.e. server time.
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (isTyping) {
      updates['typingByUser.$userId'] = FieldValue.serverTimestamp();
    } else {
      updates['typingByUser.$userId'] = FieldValue.delete();
    }

    await _firestoreService.updateDocument(
      FirestorePaths.conversation(chatId),
      updates,
    );
  }

  Future<ChatModel?> fetchConversation(String chatId) =>
      _fetchConversation(chatId);

  Future<void> _sendMessage({
    required String chatId,
    required String text,
    required ChatMessageType type,
    String? imageUrl,
    String? messageIdOverride,
  }) async {
    final senderId = _authService.currentUserId;
    if (senderId == null) {
      throw StateError('A signed-in user is required to send a message.');
    }

    final conversation = await _fetchConversation(chatId);
    if (conversation == null || !conversation.memberIds.contains(senderId)) {
      throw StateError('Only matched conversation members can send messages.');
    }
    if (!await _conversationStillAvailable(conversation)) {
      throw StateError('This conversation is no longer available.');
    }
    final senderAccount = await _fetchUser(senderId);
    if (senderAccount == null || !senderAccount.canUseDatingFeatures) {
      throw StateError('This account cannot send dating messages.');
    }

    final recipientId = conversation.memberIds.firstWhere(
      (id) => id != senderId,
      orElse: () => '',
    );
    if (recipientId.isEmpty) {
      throw StateError('A recipient is required to send a message.');
    }
    final senderHasConversationAccess = await _hasConversationActivation(
      userId: senderId,
      conversation: conversation,
    );
    if (!senderHasConversationAccess) {
      throw StateError('Activate this conversation before sending messages.');
    }

    final messageRef = messageIdOverride == null
        ? _firestoreService
              .collection(FirestorePaths.conversationMessages(chatId))
              .doc()
        : _firestoreService.document(
            FirestorePaths.conversationMessage(chatId, messageIdOverride),
          );
    final now = DateTime.now().toUtc();
    final message = ChatMessageModel(
      id: messageRef.id,
      chatId: chatId,
      senderId: senderId,
      text: text,
      type: type,
      createdAt: now,
      readByUserIds: [senderId],
      imageUrl: imageUrl,
    );

    final preview = type == ChatMessageType.image ? 'Photo' : 'New message';
    final batch = _firestoreService.batch();
    batch.set(messageRef, {
      ...message.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    // update() (not set+merge) so the dotted keys are nested field paths;
    // set+merge would create literal "typingByUser.<uid>" fields, which the
    // conversation metadata rule rejects along with the whole batch.
    batch.update(
      _firestoreService.document(FirestorePaths.conversation(chatId)),
      {
        'lastMessage': preview,
        'lastMessageType': type.name,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
        'typingByUser.$senderId': FieldValue.delete(),
        'lastReadAtByUser.$senderId': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
    await const AnalyticsEventService().track('first_message_sent');
    // Push notifications are sent by the onMessageCreated Cloud Function;
    // notification jobs are server-owned under firestore.rules.
  }

  Future<ChatModel?> _fetchConversation(String chatId) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      return null;
    }

    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.conversation(chatId),
    );
    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    final conversation = ChatModel.fromMap(snapshot.id, data);
    if (!conversation.memberIds.contains(userId)) {
      return null;
    }
    return conversation;
  }

  Future<bool> _conversationStillAvailable(ChatModel conversation) async {
    final matchSnapshot = await _firestoreService.getDocument(
      FirestorePaths.match(conversation.matchId),
    );
    final matchData = matchSnapshot.data();
    if (matchData == null) {
      return true;
    }
    final match = MatchModel.fromMap(matchSnapshot.id, matchData);
    return match.isConversationEligible;
  }

  Future<AppUser?> _fetchUser(String userId) async {
    final snapshot = await _firestoreService.getDocument(
      FirestorePaths.user(userId),
    );
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return AppUser.fromMap(userId, data);
  }

  Future<bool> _hasConversationActivation({
    required String userId,
    required ChatModel conversation,
  }) async {
    if (!AppEnvironment.firebaseEnabled) {
      return true;
    }

    final matchSnapshot = await _firestoreService.getDocument(
      FirestorePaths.match(conversation.matchId),
    );
    final matchData = matchSnapshot.data();
    if (matchData != null) {
      final match = MatchModel.fromMap(matchSnapshot.id, matchData);
      if (match.status == MatchStatus.active && match.chatId != null) {
        return true;
      }
    }

    final activationId = conversation.pairKey.isNotEmpty
        ? conversation.pairKey
        : conversation.id;
    final activation = await _firestoreService.getDocument(
      FirestorePaths.userConversationActivation(userId, activationId),
    );
    return activation.exists;
  }

  ChatModel _sanitizeConversation(
    ChatModel conversation,
    String userId,
    bool hasConversationAccess,
  ) {
    if (hasConversationAccess ||
        conversation.lastMessage.isEmpty ||
        conversation.lastMessageSenderId == null ||
        conversation.lastMessageSenderId == userId) {
      return _conversationForViewer(conversation, hasConversationAccess);
    }

    return _conversationForViewer(
      ChatModel(
        id: conversation.id,
        matchId: conversation.matchId,
        pairKey: conversation.pairKey,
        memberIds: conversation.memberIds,
        memberSnapshots: conversation.memberSnapshots,
        compatibilityScore: conversation.compatibilityScore,
        compatibilityReasons: conversation.compatibilityReasons,
        lastMessage:
            'Your match sent you a message. Activate this conversation to read and reply.',
        lastMessageType: conversation.lastMessageType,
        lastMessageAt: conversation.lastMessageAt,
        createdAt: conversation.createdAt,
        updatedAt: conversation.updatedAt,
        lastReadAtByUser: conversation.lastReadAtByUser,
        typingByUser: const {},
        lastMessageSenderId: conversation.lastMessageSenderId,
      ),
      hasConversationAccess,
    );
  }

  ChatModel _conversationForViewer(
    ChatModel conversation,
    bool hasConversationAccess,
  ) {
    return ChatModel(
      id: conversation.id,
      matchId: conversation.matchId,
      pairKey: conversation.pairKey,
      memberIds: conversation.memberIds,
      memberSnapshots: conversation.memberSnapshots,
      compatibilityScore: conversation.compatibilityScore,
      compatibilityReasons: conversation.compatibilityReasons,
      lastMessage: conversation.lastMessage,
      lastMessageType: conversation.lastMessageType,
      lastMessageAt: conversation.lastMessageAt,
      createdAt: conversation.createdAt,
      updatedAt: conversation.updatedAt,
      lastReadAtByUser: conversation.lastReadAtByUser,
      typingByUser: hasConversationAccess
          ? conversation.typingByUser
          : const {},
      lastMessageSenderId: conversation.lastMessageSenderId,
      currentUserHasConversationAccess: hasConversationAccess,
    );
  }

  ChatMessageModel _sanitizeMessage(
    ChatMessageModel message,
    String userId,
    bool hasConversationAccess,
  ) {
    if (hasConversationAccess || message.senderId == userId) {
      return message;
    }
    return ChatMessageModel(
      id: message.id,
      chatId: message.chatId,
      senderId: message.senderId,
      text: 'Activate this conversation to read this message.',
      type: message.type,
      createdAt: message.createdAt,
      readByUserIds: message.readByUserIds,
    );
  }
}
