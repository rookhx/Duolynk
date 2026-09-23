import 'package:flutter/material.dart';

import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../models/chat_model.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import 'chat_avatar.dart';

class ChatThreadTile extends StatelessWidget {
  const ChatThreadTile({
    super.key,
    required this.chat,
    required this.currentUserId,
    required this.onTap,
  });

  final ChatModel chat;
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final partnerId = chat.memberIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => currentUserId,
    );
    final partner = chat.participantFor(partnerId);
    final isTyping = _isTyping(chat.typingByUser[partnerId]);
    final subtitle = isTyping
        ? 'Typing...'
        : chat.lastMessage.isEmpty
        ? 'Start your first message'
        : chat.lastMessage;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: DuoGlassCard(
        child: Row(
          children: [
            ChatAvatar(
              name: partner?.displayName ?? 'Duolynk Member',
              photoUrl: partner?.photoUrl,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          partner?.displayName ?? 'Duolynk Member',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        '${chat.compatibilityScore}%',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isTyping
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isTyping(DateTime? updatedAt) {
    if (updatedAt == null) {
      return false;
    }
    return DateTime.now().toUtc().difference(updatedAt.toUtc()).inSeconds <= 6;
  }
}
