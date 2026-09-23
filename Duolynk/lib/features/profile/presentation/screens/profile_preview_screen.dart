import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/cards/duo_glass_card.dart';
import '../../../../theme/app_spacing.dart';
import '../controllers/profile_controller.dart';
import '../widgets/dating_profile_view.dart';

class ProfilePreviewScreen extends ConsumerWidget {
  const ProfilePreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Preview My Profile')),
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load preview.\n$error')),
        data: (state) {
          final user = state.user;
          if (user == null) {
            return const Center(child: Text('No profile found.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            children: [
              DuoGlassCard(
                child: DatingProfileView(user: user, showPreviewNotice: true),
              ),
            ],
          );
        },
      ),
    );
  }
}
