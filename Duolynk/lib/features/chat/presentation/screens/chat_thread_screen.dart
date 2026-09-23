import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/routing/app_route_paths.dart';
import '../../../../services/access/trusted_access_repository.dart';
import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../data/chat_repository.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/presentation/widgets/user_safety_actions.dart';
import '../../../matching/data/match_feedback_repository.dart';
import '../../../matching/data/matching_repository.dart';
import '../../../matching/presentation/widgets/match_feedback_sheet.dart';
import '../controllers/chat_controller.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_typing_indicator.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _typingDebounce;
  bool _isSending = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleComposerChanged);
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    unawaited(
      ref
          .read(chatRepositoryProvider)
          .setTyping(widget.chatId, isTyping: false),
    );
    _messageController
      ..removeListener(_handleComposerChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(firebaseAuthServiceProvider).currentUserId;
    final chatAsync = ref.watch(chatConversationProvider(widget.chatId));
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));

    ref.listen(chatMessagesProvider(widget.chatId), (previous, next) {
      next.whenData((_) {
        final canReadConversation =
            ref
                .read(chatConversationProvider(widget.chatId))
                .valueOrNull
                ?.currentUserHasConversationAccess ??
            false;
        if (canReadConversation) {
          unawaited(
            ref
                .read(chatRepositoryProvider)
                .markConversationRead(widget.chatId),
          );
        }
        if (_scrollController.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
              );
            }
          });
        }
      });
    });

    return Scaffold(
      body: Stack(
        children: [
          const _ThreadBackground(),
          SafeArea(
            child: chatAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => const _ThreadErrorState(),
              data: (chat) {
                if (chat == null || currentUserId == null) {
                  return const _ThreadErrorState();
                }

                final partnerId = chat.memberIds.firstWhere(
                  (id) => id != currentUserId,
                  orElse: () => '',
                );
                final partner = chat.participantFor(partnerId);
                final isPartnerTyping = _isTyping(chat.typingByUser[partnerId]);
                final hasConversationAccess =
                    chat.currentUserHasConversationAccess;
                final hasLockedIncomingMessage =
                    !hasConversationAccess &&
                    chat.lastMessageSenderId != null &&
                    chat.lastMessageSenderId != currentUserId &&
                    chat.lastMessage.isNotEmpty;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          ),
                          ChatAvatar(
                            name: partner?.displayName ?? 'Duolynk Member',
                            photoUrl: partner?.photoUrl,
                            radius: 22,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  partner?.displayName ?? 'Conversation',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 2),
                                if (isPartnerTyping)
                                  const ChatTypingIndicator(label: 'Typing')
                                else
                                  Text(
                                    partner?.country?.trim().isNotEmpty == true
                                        ? partner!.country!
                                        : 'Meaningful match',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium,
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: partner == null
                                ? null
                                : () => showUserSafetyActions(
                                    context: context,
                                    repository: ref.read(
                                      profileRepositoryProvider,
                                    ),
                                    targetUserId: partnerId,
                                    targetName: partner.displayName,
                                    source: 'chat_thread',
                                    onUnmatch: () async {
                                      final updatedMatch = await ref
                                          .read(matchingRepositoryProvider)
                                          .unmatch(chat.matchId);
                                      if (context.mounted) {
                                        await showMatchFeedbackSheet(
                                          context: context,
                                          repository: ref.read(
                                            matchFeedbackRepositoryProvider,
                                          ),
                                          match: updatedMatch,
                                        );
                                      }
                                      if (context.mounted) {
                                        context.go(AppRoutePaths.chat);
                                      }
                                    },
                                  ),
                            icon: const Icon(Icons.shield_outlined),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: messagesAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stackTrace) => const _ThreadErrorState(),
                        data: (messages) => ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            0,
                            AppSpacing.lg,
                            AppSpacing.lg,
                          ),
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isOwnMessage =
                                message.senderId == currentUserId;
                            final isRead =
                                partnerId.isNotEmpty &&
                                message.readByUserIds.contains(partnerId);
                            final showReceipt =
                                isOwnMessage && index == messages.length - 1;

                            return Align(
                              alignment: isOwnMessage
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: ChatMessageBubble(
                                message: message,
                                isOwnMessage: isOwnMessage,
                                isRead: isRead,
                                showReceipt: showReceipt,
                              ),
                            );
                          },
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemCount: messages.length,
                        ),
                      ),
                    ),
                    if (hasConversationAccess)
                      _ComposerBar(
                        controller: _messageController,
                        isSending: _isSending,
                        isUploadingImage: _isUploadingImage,
                        onSend: _sendMessage,
                        onPickImage: _sendImage,
                      )
                    else
                      _ConversationLockedBar(
                        partnerName: partner?.displayName ?? 'Your match',
                        hasIncomingMessage: hasLockedIncomingMessage,
                        matchId: chat.matchId,
                        chatId: widget.chatId,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    setState(() => _isSending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendTextMessage(chatId: widget.chatId, text: text);
      _messageController.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('We could not send that message.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _sendImage() async {
    if (_isUploadingImage) {
      return;
    }

    final picker = ref.read(chatImagePickerProvider);
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1440,
    );
    if (file == null) {
      return;
    }

    setState(() => _isUploadingImage = true);
    try {
      final bytes = await file.readAsBytes();
      await ref
          .read(chatRepositoryProvider)
          .sendImageMessage(
            chatId: widget.chatId,
            bytes: bytes,
            fileName: file.name,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('We could not share that image.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _handleComposerChanged() {
    final hasContent = _messageController.text.trim().isNotEmpty;
    unawaited(
      ref
          .read(chatRepositoryProvider)
          .setTyping(widget.chatId, isTyping: hasContent),
    );

    _typingDebounce?.cancel();
    if (!hasContent) {
      return;
    }

    _typingDebounce = Timer(const Duration(seconds: 2), () {
      unawaited(
        ref
            .read(chatRepositoryProvider)
            .setTyping(widget.chatId, isTyping: false),
      );
    });
  }

  bool _isTyping(DateTime? updatedAt) {
    if (updatedAt == null) {
      return false;
    }
    return DateTime.now().toUtc().difference(updatedAt.toUtc()).inSeconds <= 6;
  }
}

class _ConversationLockedBar extends ConsumerStatefulWidget {
  const _ConversationLockedBar({
    required this.partnerName,
    required this.hasIncomingMessage,
    required this.matchId,
    required this.chatId,
  });

  final String partnerName;
  final bool hasIncomingMessage;
  final String matchId;
  final String chatId;

  @override
  ConsumerState<_ConversationLockedBar> createState() =>
      _ConversationLockedBarState();
}

class _ConversationLockedBarState
    extends ConsumerState<_ConversationLockedBar> {
  bool _isActivating = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: DuoGlassCard(
        child: Column(
          children: [
            Text(
              widget.hasIncomingMessage
                  ? 'You matched'
                  : 'Activate Conversation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.hasIncomingMessage
                  ? '${widget.partnerName} sent you a message. Activate this conversation to read and reply.'
                  : 'Your matches and messages stay here. Basic includes 1 new conversation activation each week; Premium includes up to 3.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            DuoButton(
              label: 'Activate Conversation',
              isLoading: _isActivating,
              onPressed: _isActivating ? null : () => _activate(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _activate(BuildContext context) async {
    setState(() => _isActivating = true);
    try {
      final result = await ref
          .read(trustedAccessRepositoryProvider)
          .activateConversation(matchId: widget.matchId);
      if (!context.mounted) {
        return;
      }
      if (result.succeeded) {
        ref.invalidate(chatConversationProvider(widget.chatId));
        ref.invalidate(chatMessagesProvider(widget.chatId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation activated.')),
        );
      } else if (result.status == 'quotaReached') {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Weekly activation used'),
            content: const Text(
              "You've used this week's Basic conversation activation. Premium lets you start up to 3 new conversations each week.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Not now'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutePaths.subscription);
                },
                child: const Text('View Premium'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('We could not activate this conversation.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('We could not activate this conversation.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActivating = false);
      }
    }
  }
}

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.controller,
    required this.isSending,
    required this.isUploadingImage,
    required this.onSend,
    required this.onPickImage,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool isUploadingImage;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.cardStroke),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: isUploadingImage ? null : onPickImage,
              icon: isUploadingImage
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Write something thoughtful...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            IconButton(
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadErrorState extends StatelessWidget {
  const _ThreadErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'We could not load this conversation.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}

class _ThreadBackground extends StatelessWidget {
  const _ThreadBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.background),
      child: Stack(
        children: [
          Positioned(
            top: -140,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x26FF3E9E),
                    Color(0x10B26BFF),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
