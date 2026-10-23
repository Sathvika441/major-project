import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:major_proj_1/core/storage/local_storage_service.dart';
import 'package:major_proj_1/features/auth/controllers/auth_controller.dart';
import 'package:major_proj_1/features/auth/screens/login_screen.dart';
import 'package:major_proj_1/main.dart';
import 'package:major_proj_1/models/farm/farm_model.dart';
import 'package:major_proj_1/models/user/user_model.dart';
import 'package:major_proj_1/repositories/auth/auth_repository.dart';
import 'package:major_proj_1/repositories/farm/farm_repository.dart';
import 'package:major_proj_1/services/otp/otp_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('ArecaSmartApp launches cleanly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final localStorage = await LocalStorageService.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(localStorage),
        ],
        child: const ArecaSmartApp(),
      ),
    );

    await tester.pump();

    expect(find.text('ArecaSmart'), findsOneWidget);
  });

  testWidgets('login screen opens the sign-up screen', (
    WidgetTester tester,
  ) async {
    await _pumpLoginScreen(tester);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('login screen offers Google sign-in', (
    WidgetTester tester,
  ) async {
    await _pumpLoginScreen(tester);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}

Future<void> _pumpLoginScreen(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final localStorage = await LocalStorageService.init();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(localStorage),
        authRepositoryProvider.overrideWith((ref) => _FakeAuthRepository()),
        farmRepositoryProvider.overrideWith((ref) => _FakeFarmRepository()),
        authControllerProvider.overrideWith(
          (ref) => AuthController(
            ref.watch(authRepositoryProvider),
            ref.watch(otpServiceProvider),
            ref.watch(localStorageServiceProvider),
            ref.watch(farmRepositoryProvider),
          ),
        ),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ),
  );

  await tester.pump();
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<UserModel?> getSavedSession() async => null;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<UserModel> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<UserModel> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> sendEmailVerification() => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<void> updateCurrentUser(UserModel user) => throw UnimplementedError();
}

class _FakeFarmRepository implements FarmRepository {
  @override
  Future<List<FarmModel>> getFarms(String userId) async => [];

  @override
  Stream<List<FarmModel>> watchFarms(String userId) => Stream.value([]);

  @override
  Future<FarmModel> saveFarm(FarmModel farm) => throw UnimplementedError();

  @override
  Future<void> deactivateFarm(String userId, String farmId) =>
      throw UnimplementedError();

  @override
  Future<List<PlotModel>> getPlots(String userId, String farmId) async => [];

  @override
  Future<PlotModel> savePlot(String userId, PlotModel plot) =>
      throw UnimplementedError();

  @override
  Future<void> deactivatePlot(String userId, String farmId, String plotId) =>
      throw UnimplementedError();
}
