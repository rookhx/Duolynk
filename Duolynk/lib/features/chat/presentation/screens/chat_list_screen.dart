import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/routing/app_route_paths.dart';
import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../core/widgets/layout/duo_primary_scaffold.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../../matching/data/matching_repository.dart';
import '../../data/chat_repository.dart';
import '../controllers/chat_controller.dart';
import '../widgets/chat_match_card.dart';
import '../widgets/chat_thread_tile.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String? _openingMatchId;

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatThreadsProvider);
    final matchesAsync = ref.watch(chatMatchedCandidatesProvider);
    final currentUserId = ref.watch(firebaseAuthServiceProvider).currentUserId;

    return DuoPrimaryScaffold(
      currentIndex: 1,
      title: 'Conversations',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(chatThreadsProvider);
          ref.invalidate(chatMatchedCandidatesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'Meaningful chats open only after a genuine compatibility match.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            matchesAsync.when(
              loading: () => const _SectionLoadingCard(),
              error: (error, stackTrace) => const _SectionErrorCard(
                message: 'We could not load your available matches.',
              ),
              data: (candidates) {
                final readyToBegin = candidates
                    .where((candidate) => candidate.match.chatId == null)
                    .toList();

                if (readyToBegin.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready To Begin',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...readyToBegin.map(
                      (candidate) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: ChatMatchCard(
                          candidate: candidate,
                          isOpening: _openingMatchId == candidate.match.id,
                          onOpen: () => _openMatch(candidate.match.id),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                );
              },
            ),
            Text(
              'Recent Messages',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            chatsAsync.when(
              loading: () => const _SectionLoadingCard(),
              error: (error, stackTrace) => const _SectionErrorCard(
                message: 'We could not load your conversations.',
              ),
              data: (threads) {
                if (threads.isEmpty) {
                  return DuoGlassCard(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 56,
                          color: AppColors.accent,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'No conversations yet',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'When you decide to begin with a match, your conversation will appear here in real time.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: threads
                      .map(
                        (chat) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: ChatThreadTile(
                            chat: chat,
                            currentUserId: currentUserId ?? '',
                            onTap: () =>
                                context.push(AppRoutePaths.chatThread(chat.id)),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMatch(String matchId) async {
    setState(() => _openingMatchId = matchId);

    try {
      final matches = await ref
          .read(matchingRepositoryProvider)
          .watchActiveMatches()
          .first;
      final match = matches.firstWhere((item) => item.id == matchId);
      final chatId = await ref
          .read(chatRepositoryProvider)
          .ensureConversationForMatch(match);
      if (mounted) {
        context.push(AppRoutePaths.chatThread(chatId));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('We could not open this conversation right now.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _openingMatchId = null);
      }
    }
  }
}

class _SectionLoadingCard extends StatelessWidget {
  const _SectionLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const DuoGlassCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _SectionErrorCard extends StatelessWidget {
  const _SectionErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DuoGlassCard(
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
