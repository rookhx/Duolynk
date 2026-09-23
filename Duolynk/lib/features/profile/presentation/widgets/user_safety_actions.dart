import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../models/user_report.dart';
import '../../../../services/analytics/analytics_event_service.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../data/profile_repository.dart';

Future<void> showUserSafetyActions({
  required BuildContext context,
  required ProfileRepository repository,
  required String targetUserId,
  required String targetName,
  required String source,
  Future<void> Function()? onUnmatch,
  VoidCallback? onCompleted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _SafetySheet(
      repository: repository,
      targetUserId: targetUserId,
      targetName: targetName,
      source: source,
      onUnmatch: onUnmatch,
      onCompleted: onCompleted,
    ),
  );
}

class _SafetySheet extends StatelessWidget {
  const _SafetySheet({
    required this.repository,
    required this.targetUserId,
    required this.targetName,
    required this.source,
    this.onUnmatch,
    this.onCompleted,
  });

  final ProfileRepository repository;
  final String targetUserId;
  final String targetName;
  final String source;
  final Future<void> Function()? onUnmatch;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: DuoGlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(targetName, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Control how this member can interact with you, or flag behavior that should be reviewed.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (onUnmatch != null) ...[
              DuoButton(
                label: 'Unmatch',
                variant: DuoButtonVariant.secondary,
                onPressed: () async {
                  Navigator.of(context).pop();
                  final confirmed = await _showUnmatchDialog(
                    context: context,
                    targetName: targetName,
                  );
                  if (confirmed != true) {
                    return;
                  }
                  await onUnmatch!();
                  onCompleted?.call();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'This conversation is no longer available.',
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            DuoButton(
              label: 'Block User',
              variant: DuoButtonVariant.secondary,
              onPressed: () async {
                Navigator.of(context).pop();
                await repository.blockUser(targetUserId: targetUserId);
                onCompleted?.call();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$targetName has been blocked.')),
                  );
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            DuoButton(
              label: 'Report User',
              onPressed: () async {
                Navigator.of(context).pop();
                await _showReportDialog(
                  context: context,
                  repository: repository,
                  targetUserId: targetUserId,
                  targetName: targetName,
                  source: source,
                );
                onCompleted?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _showUnmatchDialog({
  required BuildContext context,
  required String targetName,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Unmatch $targetName?'),
      content: const Text('You will no longer be able to message each other.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Unmatch'),
        ),
      ],
    ),
  );
}

Future<void> _showReportDialog({
  required BuildContext context,
  required ProfileRepository repository,
  required String targetUserId,
  required String targetName,
  required String source,
}) async {
  final detailsController = TextEditingController();
  var selectedCategory = ReportCategory.harassment;

  try {
    unawaited(const AnalyticsEventService().track('report_started'));
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Report $targetName'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final reason in const [
                          ReportCategory.fakeProfile,
                          ReportCategory.scam,
                          ReportCategory.harassment,
                          ReportCategory.sexualContent,
                          ReportCategory.hate,
                          ReportCategory.underageConcern,
                          ReportCategory.dangerousBehavior,
                          ReportCategory.spam,
                          ReportCategory.stolenPhotos,
                          ReportCategory.other,
                        ])
                          ChoiceChip(
                            label: Text(UserReport.labelFor(reason)),
                            selected: selectedCategory == reason,
                            onSelected: (_) =>
                                setState(() => selectedCategory = reason),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: detailsController,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: UserReport.detailsCharacterLimit,
                      decoration: const InputDecoration(
                        hintText: 'Optional: add anything helpful for review.',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (submitted == true) {
      await repository.reportUser(
        targetUserId: targetUserId,
        category: selectedCategory,
        details: detailsController.text.trim().isEmpty
            ? null
            : detailsController.text.trim(),
        source: source,
      );
      await const AnalyticsEventService().track('report_submitted');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted for review.')),
        );
      }
      if (context.mounted) {
        final shouldBlock = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Block this person?'),
            content: const Text(
              'Blocking also stops future contact and recommendations.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Block'),
              ),
            ],
          ),
        );
        if (shouldBlock == true) {
          await repository.blockUser(targetUserId: targetUserId);
          await const AnalyticsEventService().track('block_after_report');
        }
      }
    }
  } finally {
    detailsController.dispose();
  }
}
