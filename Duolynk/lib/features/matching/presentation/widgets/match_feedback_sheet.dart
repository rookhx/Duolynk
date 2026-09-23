import 'package:flutter/material.dart';

import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../models/match_feedback.dart';
import '../../../../models/match_model.dart';
import '../../../../services/analytics/analytics_event_service.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../data/match_feedback_repository.dart';

Future<void> showMatchFeedbackSheet({
  required BuildContext context,
  required MatchFeedbackRepository repository,
  required MatchModel match,
}) async {
  await const AnalyticsEventService().track('match_feedback_prompted');
  if (!context.mounted) {
    return;
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _MatchFeedbackSheet(repository: repository, match: match),
  );
}

class _MatchFeedbackSheet extends StatefulWidget {
  const _MatchFeedbackSheet({required this.repository, required this.match});

  final MatchFeedbackRepository repository;
  final MatchModel match;

  @override
  State<_MatchFeedbackSheet> createState() => _MatchFeedbackSheetState();
}

class _MatchFeedbackSheetState extends State<_MatchFeedbackSheet> {
  final _selectedReasons = <MatchFeedbackReason>{};
  bool _goodMatch = false;
  bool _metInPerson = false;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          top: AppSpacing.lg,
        ),
        child: DuoGlassCard(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help improve your matches',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'What best describes this connection? Your feedback stays private.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final reason in _feedbackReasons)
                      FilterChip(
                        label: Text(reason.label),
                        selected: _selectedReasons.contains(reason),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedReasons.add(reason);
                            } else {
                              _selectedReasons.remove(reason);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                CheckboxListTile(
                  value: _goodMatch,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('It was actually a good match'),
                  onChanged: (value) =>
                      setState(() => _goodMatch = value ?? false),
                ),
                CheckboxListTile(
                  value: _metInPerson,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('We met in person'),
                  onChanged: (value) =>
                      setState(() => _metInPerson = value ?? false),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: DuoButton(
                        label: 'Skip',
                        variant: DuoButtonVariant.secondary,
                        onPressed: _isSubmitting ? null : _skip,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DuoButton(
                        label: 'Submit',
                        isLoading: _isSubmitting,
                        onPressed: _isSubmitting ? null : _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _skip() async {
    await widget.repository.skipFeedback();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.repository.submitFeedback(
        match: widget.match,
        reasons: _selectedReasons,
        goodMatch: _goodMatch,
        metInPerson: _metInPerson,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  static const _feedbackReasons = [
    MatchFeedbackReason.differentThings,
    MatchFeedbackReason.lifestylesDidntFit,
    MatchFeedbackReason.personalitiesDidntClick,
    MatchFeedbackReason.communicationDidntFeelRight,
    MatchFeedbackReason.distanceWasIssue,
    MatchFeedbackReason.notEnoughSharedInterests,
    MatchFeedbackReason.attractionWasntThere,
    MatchFeedbackReason.timingWasntRight,
    MatchFeedbackReason.metButNotMatch,
    MatchFeedbackReason.preferNotToSay,
  ];
}
