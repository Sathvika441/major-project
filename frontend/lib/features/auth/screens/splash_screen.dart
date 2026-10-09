import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_storage_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  static const _minSplashDuration = Duration(milliseconds: 2000);
  bool _animationDone = false;
  bool _authCheckDone = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward().then((_) async {
      await Future.delayed(
        _minSplashDuration - const Duration(milliseconds: 1200),
      );
      if (mounted) {
        setState(() => _animationDone = true);
        _tryNavigate();
      }
    });

    Future.microtask(() {
      final authState = ref.read(authControllerProvider);
      if (authState.status != AuthStatus.initial &&
          authState.status != AuthStatus.loading) {
        _authCheckDone = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryNavigate());
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _tryNavigate() {
    if (!mounted || _navigated) return;
    if (!_animationDone || !_authCheckDone) return;

    final authState = ref.read(authControllerProvider);
    final storage = ref.read(localStorageServiceProvider);
    _navigated = true;

    switch (authState.status) {
      case AuthStatus.authenticated:
        final completed = storage.hasCompletedOnboarding();
        context.go(completed ? '/' : '/onboarding');
        break;
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
      case AuthStatus.emailVerificationPending:
      default:
        context.go('/');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.status != AuthStatus.initial &&
          next.status != AuthStatus.loading) {
        if (!_authCheckDone) {
          _authCheckDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _tryNavigate());
        }
      }
    });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/arecanut06jpg.jpeg', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xA6000805),
                  Color(0xD9000805),
                  Color(0xF2000805),
                ],
              ),
            ),
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // App Icon / Logo Emblem
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F9A62).withValues(alpha: 0.28),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.eco_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // App Title & Tagline
                const Text(
                  'ArecaSmart',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Precision Irrigation & Crop Health Intelligence',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const Spacer(),
                // Loading indicator
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'Version 1.0.0 (Phase 0 & 1 Architecture)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
