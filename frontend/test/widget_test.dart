import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:major_proj_1/core/storage/local_storage_service.dart';
import 'package:major_proj_1/features/auth/controllers/auth_controller.dart';
import 'package:major_proj_1/features/auth/screens/login_screen.dart';
import 'package:major_proj_1/main.dart';
import 'package:major_proj_1/models/farm/farm_model.dart';
import 'package:major_proj_1/models/user/user_model.dart';
import 'package:major_proj_1/repositories/farm/farm_repository.dart';
import 'package:major_proj_1/services/auth/auth_service.dart';
import 'package:major_proj_1/services/otp/otp_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthService implements AuthService {
  @override
  Future<UserModel> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<UserModel> login({required String email, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<UserModel> signInWithGoogle() async => throw UnimplementedError();

  @override
  Future<void> updateCurrentUser(UserModel user) async =>
      throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail(String email) async =>
      throw UnimplementedError();

  @override
  Future<void> sendEmailVerification() async => throw UnimplementedError();

  @override
  Future<UserModel?> getCurrentUser() async => null;

  @override
  Future<void> logout() async {}
}

class _FakeFarmRepository implements FarmRepository {
  @override
  Future<List<FarmModel>> getFarms(String userId) async => [];

  @override
  Stream<List<FarmModel>> watchFarms(String userId) => const Stream.empty();

  @override
  Future<FarmModel> saveFarm(FarmModel farm) async =>
      throw UnimplementedError();

  @override
  Future<void> deactivateFarm(String userId, String farmId) async =>
      throw UnimplementedError();

  @override
  Future<List<PlotModel>> getPlots(String userId, String farmId) async => [];

  @override
  Future<PlotModel> savePlot(String userId, PlotModel plot) async =>
      throw UnimplementedError();

  @override
  Future<void> deactivatePlot(
    String userId,
    String farmId,
    String plotId,
  ) async => throw UnimplementedError();
}

void main() {
  Future<void> pumpLoginScreen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final localStorage = await LocalStorageService.init();
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(localStorage),
          authServiceProvider.overrideWithValue(_FakeAuthService()),
          farmRepositoryProvider.overrideWithValue(_FakeFarmRepository()),
          otpServiceProvider.overrideWith((ref) => OtpService(localStorage.raw)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ArecaSmartApp launches cleanly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final localStorage = await LocalStorageService.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(localStorage),
          authServiceProvider.overrideWithValue(_FakeAuthService()),
          farmRepositoryProvider.overrideWithValue(_FakeFarmRepository()),
          otpServiceProvider.overrideWith((ref) => OtpService(localStorage.raw)),
        ],
        child: const ArecaSmartApp(),
      ),
    );

    // The splash screen has repeating animations, so pump a bounded frame
    // instead of waiting for all animations to settle.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ArecaSmart'), findsWidgets);
  });

  testWidgets('login screen offers Google sign-in', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
