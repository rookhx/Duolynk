import 'package:flutter/material.dart';

import '../../../../models/chat_model.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_radii.dart';
import '../../../../theme/app_spacing.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isOwnMessage,
    required this.isRead,
    required this.showReceipt,
  });

  final ChatMessageModel message;
  final bool isOwnMessage;
  final bool isRead;
  final bool showReceipt;

  @override
  Widget build(BuildContext context) {
    final alignment = isOwnMessage
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: EdgeInsets.all(
            message.type == ChatMessageType.image
                ? AppSpacing.xs
                : AppSpacing.md,
          ),
          decoration: BoxDecoration(
            gradient: isOwnMessage
                ? const LinearGradient(
                    colors: [AppColors.primaryStart, AppColors.primaryEnd],
                  )
                : null,
            color: isOwnMessage ? null : AppColors.bubbleOther,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadii.medium),
              topRight: const Radius.circular(AppRadii.medium),
              bottomLeft: Radius.circular(isOwnMessage ? AppRadii.medium : 8),
              bottomRight: Radius.circular(isOwnMessage ? 8 : AppRadii.medium),
            ),
            border: isOwnMessage
                ? null
                : Border.all(color: AppColors.cardStroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.type == ChatMessageType.image &&
                  message.imageUrl != null &&
                  message.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  child: Image.network(
                    message.imageUrl!,
                    width: 284,
                    fit: BoxFit.cover,
                  ),
                ),
              if (message.text.trim().isNotEmpty) ...[
                if (message.type == ChatMessageType.image)
                  const SizedBox(height: AppSpacing.sm),
                Text(
                  message.text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ],
          ),
        ),
        if (showReceipt) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            isRead ? 'Read' : 'Sent',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}
