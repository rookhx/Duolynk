import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../routing/app_route_paths.dart';

class DuoPrimaryScaffold extends StatelessWidget {
  const DuoPrimaryScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    this.title,
    this.actions,
    this.appBar,
  });

  final Widget body;
  final int currentIndex;
  final String? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    final resolvedAppBar =
        appBar ??
        (title == null ? null : AppBar(title: Text(title!), actions: actions));

    return Scaffold(
      extendBody: true,
      appBar: resolvedAppBar,
      body: Stack(
        children: [
          const DuoAtmosphereBackground(),
          SafeArea(child: body),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: NavigationBar(
            height: 76,
            backgroundColor: AppColors.surface.withValues(alpha: 0.96),
            selectedIndex: currentIndex,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.favorite_outline_rounded),
                selectedIcon: Icon(Icons.favorite_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.forum_outlined),
                selectedIcon: Icon(Icons.forum_rounded),
                label: 'Chat',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
            onDestinationSelected: (index) =>
                _onDestinationSelected(context, index),
          ),
        ),
      ),
    );
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutePaths.matching);
        break;
      case 1:
        context.go(AppRoutePaths.chat);
        break;
      case 2:
        context.go(AppRoutePaths.profile);
        break;
    }
  }
}

class DuoAtmosphereBackground extends StatelessWidget {
  const DuoAtmosphereBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.background),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -40,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x28FF3E9E),
                    Color(0x18B26BFF),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -30,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x227B2FFF),
                    Color(0x10FF3E9E),
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
