import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/storage/local_storage_service.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/controllers/auth_state.dart';
import '../features/auth/screens/email_verification_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/otp_verification_screen.dart';
import '../features/auth/screens/permission_setup_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/weather/screens/weather_screen.dart';
import '../features/devices/screens/device_management_screen.dart';
import '../features/farm/screens/farm_details_screen.dart';
import '../features/farm/screens/farm_management_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/profile/screens/profile_edit_screen.dart';
import '../models/farm/farm_profile_model.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final storage = ref.watch(localStorageServiceProvider);

  bool legacyFarmDetailsMissing() {
    final user = authState.user;
    if (user == null || !storage.hasCompletedOnboarding()) return false;
    final raw = storage.raw.getString('phase25_profile_${user.uid}');
    if (raw == null || raw.isEmpty) return true;
    try {
      final profile = FarmProfileModel.fromJson(raw);
      return profile.landSurveyNumber.trim().isEmpty ||
          profile.arecanutCultivationType.trim().isEmpty ||
          profile.soilType.trim().isEmpty;
    } catch (_) {
      return true;
    }
  }

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/weather',
        builder: (context, state) =>
            WeatherScreen(key: ValueKey(state.uri.queryParameters['refresh'])),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
        path: '/otp-verification',
        builder: (context, state) => const OtpVerificationScreen(),
      ),
      GoRoute(
        path: '/permission-setup',
        builder: (context, state) => const PermissionSetupScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/farm-details',
        builder: (context, state) => const FarmDetailsScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/farm/:farmId',
        builder: (context, state) =>
            DashboardScreen(initialFarmId: state.pathParameters['farmId']),
      ),
      GoRoute(
        path: '/farms',
        builder: (context, state) => const FarmManagementScreen(),
      ),
      GoRoute(
        path: '/devices',
        builder: (context, state) => const DeviceManagementScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileEditScreen(),
      ),
    ],
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isSplash = location == '/splash';
      final isAuthRoute =
          location == '/login' ||
          location == '/signup' ||
          location == '/forgot-password';
      final isPublicRoute =
          isSplash ||
          isAuthRoute ||
          location == '/verify-email' ||
          location == '/' ||
          location == '/weather';

      if (authState.status == AuthStatus.initial ||
          authState.status == AuthStatus.loading) {
        return isSplash ? null : '/splash';
      }

      if (authState.status == AuthStatus.unauthenticated ||
          authState.status == AuthStatus.error ||
          authState.status == AuthStatus.emailVerificationPending) {
        return isPublicRoute
            ? null
            : '/login?prompt=Sign%20in%20to%20save%20your%20farm';
      }

      if (authState.status == AuthStatus.otpVerificationPending) {
        return location == '/otp-verification' ? null : '/otp-verification';
      }

      if (authState.status != AuthStatus.authenticated) return null;

      // Normal login is an existing-user flow. Never restart onboarding
      // just because local phase flags are incomplete or stale.
      if (!storage.isOnboardingRequired()) {
        if (isAuthRoute ||
            isSplash ||
            location == '/otp-verification' ||
            location == '/permission-setup' ||
            location == '/onboarding' ||
            location == '/farm-details') {
          return '/';
        }
        return null;
      }

      // Task 12: old users that already finished the original onboarding are
      // migrated in AuthController before authenticated state is published.
      final phaseADone = storage.hasCompletedPhaseA();
      final phaseBDone = storage.hasCompletedPhaseB();
      final migrationNeeded = legacyFarmDetailsMissing();

      if (migrationNeeded) {
        return location == '/farm-details' ? null : '/farm-details';
      }

      if (!phaseADone) {
        return location == '/onboarding' ? null : '/onboarding';
      }

      if (!phaseBDone) {
        return location == '/farm-details' ? null : '/farm-details';
      }

      if (isAuthRoute ||
          isSplash ||
          location == '/otp-verification' ||
          location == '/permission-setup' ||
          location == '/onboarding' ||
          location == '/farm-details') {
        return '/dashboard';
      }

      return null;
    },
  );
});
