import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/controllers/auth_state.dart';
import '../features/auth/screens/email_verification_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/farm/screens/farm_management_screen.dart';
import '../features/devices/screens/device_management_screen.dart';
import '../features/profile/screens/profile_edit_screen.dart';
import '../core/storage/local_storage_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final storage = ref.watch(localStorageServiceProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/verify-email', builder: (context, state) => const EmailVerificationScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/farms', builder: (context, state) => const FarmManagementScreen()),
      GoRoute(path: '/devices', builder: (context, state) => const DeviceManagementScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileEditScreen()),
    ],
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isSplash = location == '/splash';
      final isAuthRoute = location == '/login' || location == '/signup' || location == '/forgot-password';
      final isPublicRoute = isSplash || isAuthRoute || location == '/verify-email';

      if (authState.status == AuthStatus.initial || authState.status == AuthStatus.loading) {
        return isSplash ? null : '/splash';
      }
      if (authState.status == AuthStatus.unauthenticated ||
          authState.status == AuthStatus.error ||
          authState.status == AuthStatus.emailVerificationPending) {
        return isPublicRoute ? null : '/login';
      }
      if (authState.status == AuthStatus.authenticated) {
        if (isAuthRoute || isSplash) {
          final completed = storage.hasCompletedOnboarding();
          return completed ? '/dashboard' : '/onboarding';
        }
      }
      return null;
    },
  );
});
