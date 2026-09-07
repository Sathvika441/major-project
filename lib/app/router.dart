import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/controllers/auth_state.dart';
import '../features/auth/screens/email_verification_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/dashboard/screens/placeholder_dashboard_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const PlaceholderDashboardScreen(),
      ),
    ],
    redirect: (context, state) {
      final isSplash = state.matchedLocation == '/splash';
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/forgot-password';

      // 1. Initial / Loading State: show splash screen
      if (authState.status == AuthStatus.initial || authState.status == AuthStatus.loading) {
        return isSplash ? null : '/splash';
      }

      // 2. Authenticated State: redirect to dashboard if trying to access auth/splash routes
      if (authState.status == AuthStatus.authenticated) {
        if (isSplash || isAuthRoute) {
          return '/dashboard';
        }
        return null;
      }

      // 3. Unauthenticated State: redirect to login if trying to access protected routes
      if (authState.status == AuthStatus.unauthenticated || authState.status == AuthStatus.error) {
        if (state.matchedLocation == '/dashboard' || isSplash) {
          return '/login';
        }
        return null;
      }

      return null;
    },
  );
});
