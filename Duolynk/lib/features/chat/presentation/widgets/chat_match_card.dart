import 'package:flutter/material.dart';

import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../domain/chat_match_candidate.dart';
import 'chat_avatar.dart';

class ChatMatchCard extends StatelessWidget {
  const ChatMatchCard({
    super.key,
    required this.candidate,
    required this.onOpen,
    this.isOpening = false,
  });

  final ChatMatchCandidate candidate;
  final VoidCallback onOpen;
  final bool isOpening;

  @override
  Widget build(BuildContext context) {
    return DuoGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChatAvatar(
                name: candidate.partner.displayName,
                photoUrl: candidate.partner.photoUrls.isNotEmpty
                    ? candidate.partner.photoUrls.first
                    : candidate.partner.photoUrl,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${candidate.partner.displayName}, ${candidate.partner.displayAge()}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      candidate.partner.country?.trim().isNotEmpty == true
                          ? candidate.partner.country!
                          : 'Location pending',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.cardStroke),
                ),
                child: Text(
                  '${candidate.match.compatibilityScore}%',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Why this conversation matters',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...candidate.match.compatibilityReasons
              .take(3)
              .map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    '• ${reason.description}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.md),
          DuoButton(
            label: candidate.match.chatId == null
                ? 'Start Conversation'
                : 'Open Chat',
            isLoading: isOpening,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}
