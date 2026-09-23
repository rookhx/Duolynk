import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/buttons/duo_button.dart';
import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../models/notification_preferences.dart';
import '../../../../theme/app_spacing.dart';
import '../../data/profile_repository.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  NotificationPreferences? _preferences;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await ref
        .read(profileRepositoryProvider)
        .fetchNotificationPreferences();
    if (mounted) {
      setState(() => _preferences = preferences);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = _preferences;

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: preferences == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              children: [
                DuoGlassCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: preferences.pushEnabled,
                        onChanged: (value) => setState(
                          () => _preferences = preferences.copyWith(
                            pushEnabled: value,
                          ),
                        ),
                        title: const Text('Push Notifications'),
                      ),
                      SwitchListTile(
                        value: preferences.newIntroductions,
                        onChanged: (value) => setState(
                          () => _preferences = preferences.copyWith(
                            newIntroductions: value,
                          ),
                        ),
                        title: const Text('New introductions'),
                        subtitle: const Text('Duolynk found someone for you.'),
                      ),
                      SwitchListTile(
                        value: preferences.matchUpdates,
                        onChanged: (value) => setState(
                          () => _preferences = preferences.copyWith(
                            matchUpdates: value,
                          ),
                        ),
                        title: const Text('Match updates'),
                        subtitle: const Text(
                          "Mutual matches and important match changes.",
                        ),
                      ),
                      SwitchListTile(
                        value: preferences.messages,
                        onChanged: (value) => setState(
                          () => _preferences = preferences.copyWith(
                            messages: value,
                          ),
                        ),
                        title: const Text('Messages'),
                      ),
                      SwitchListTile(
                        value: preferences.reminders,
                        onChanged: (value) => setState(
                          () => _preferences = preferences.copyWith(
                            reminders: value,
                          ),
                        ),
                        title: const Text('Reminders'),
                        subtitle: const Text(
                          'A single reminder before an introduction expires.',
                        ),
                      ),
                      SwitchListTile(
                        value: preferences.marketing,
                        onChanged: (value) => setState(
                          () => _preferences = preferences.copyWith(
                            marketing: value,
                          ),
                        ),
                        title: const Text('Product Updates'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                DuoButton(
                  label: 'Save Preferences',
                  isLoading: _isSaving,
                  onPressed: () => _save(preferences),
                ),
              ],
            ),
    );
  }

  Future<void> _save(NotificationPreferences preferences) async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .saveNotificationPreferences(preferences);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification preferences saved.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
