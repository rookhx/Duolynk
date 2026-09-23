import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/app_startup_provider.dart';
import '../../../../core/routing/app_route_paths.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_spacing.dart';
import '../../domain/auth_session.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_brand_mark.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _minimumDelayComplete = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1350), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _minimumDelayComplete = true;
      });
      _maybeNavigate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final startup = ref.watch(appStartupProvider);
    final authSession = ref.watch(authSessionProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeNavigate();
      }
    });

    final helperText = startup.hasError
        ? 'A few services still need configuration, but the app foundation is ready.'
        : authSession.isLoading || startup.isLoading
        ? 'Preparing a more intentional way to connect.'
        : 'Entering your compatibility-first experience.';

    return Scaffold(
      body: Stack(
        children: [
          const _SplashBackground(),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.86, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(scale: value, child: child);
                    },
                    child: const AuthBrandMark(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AnimatedOpacity(
                    opacity: 1,
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      helperText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _maybeNavigate() {
    if (_hasNavigated || !_minimumDelayComplete) {
      return;
    }

    final startup = ref.read(appStartupProvider);
    final authSession = ref.read(authSessionProvider);

    if (startup.isLoading || authSession.isLoading) {
      return;
    }

    final target = _resolveTarget(authSession.valueOrNull);
    _hasNavigated = true;
    context.go(target);
  }

  String _resolveTarget(AuthSession? session) {
    if (session?.isAuthenticated != true) {
      return AppRoutePaths.login;
    }

    return session!.needsOnboarding
        ? AppRoutePaths.onboarding
        : AppRoutePaths.matching;
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.background),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x30FF3E9E),
                    Color(0x1AB26BFF),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -40,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x2AB26BFF),
                    Color(0x16FF3E9E),
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
