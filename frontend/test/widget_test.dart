import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:major_proj_1/core/storage/local_storage_service.dart';
import 'package:major_proj_1/features/auth/controllers/auth_controller.dart';
import 'package:major_proj_1/features/auth/screens/login_screen.dart';
import 'package:major_proj_1/main.dart';
import 'package:major_proj_1/repositories/farm/farm_repository.dart';
import 'package:major_proj_1/repositories/auth/auth_repository.dart';
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

class _FakeOtpService extends OtpService {
  _FakeOtpService(super.prefs);
}

void main() {
  Future<ProviderContainer> pumpLoginScreen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final localStorage = await LocalStorageService.init();
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(localStorage),
        authServiceProvider.overrideWithValue(_FakeAuthService()),
        farmRepositoryProvider.overrideWithValue(_FakeFarmRepository()),
        otpServiceProvider.overrideWith(_FakeOtpService.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
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
          otpServiceProvider.overrideWith(_FakeOtpService.new),
        ],
        child: const ArecaSmartApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ArecaSmart'), findsOneWidget);
  });

  testWidgets('login screen offers Google sign-in', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
