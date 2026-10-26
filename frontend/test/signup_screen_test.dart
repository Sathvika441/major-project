import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:major_proj_1/core/storage/local_storage_service.dart';
import 'package:major_proj_1/features/auth/controllers/auth_controller.dart';
import 'package:major_proj_1/features/auth/screens/signup_screen.dart';
import 'package:major_proj_1/models/farm/farm_model.dart';
import 'package:major_proj_1/models/user/user_model.dart';
import 'package:major_proj_1/repositories/farm/farm_repository.dart';
import 'package:major_proj_1/services/auth/auth_service.dart';
import 'package:major_proj_1/services/otp/otp_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthService implements AuthService {
  @override
  Future<UserModel> signUp({required String name, required String email, required String phone, required String password}) async =>
      UserModel(uid: 'test-user', name: name, email: email, phone: phone, createdAt: DateTime(2026));

  @override
  Future<UserModel> login({required String email, required String password}) async =>
      throw UnimplementedError();
  @override
  Future<UserModel> signInWithGoogle() async => throw UnimplementedError();
  @override
  Future<void> updateCurrentUser(UserModel user) async {}
  @override
  Future<void> sendPasswordResetEmail(String email) async {}
  @override
  Future<void> sendEmailVerification() async {}
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
  testWidgets('registration button creates an account and opens OTP verification', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.init();
    final router = GoRouter(
      initialLocation: '/signup',
      routes: [
        GoRoute(
          path: '/signup',
          builder: (context, state) => const SignupScreen(),
        ),
        GoRoute(
          path: '/otp-verification',
          builder: (context, state) => const Text('Verify Phone'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          authServiceProvider.overrideWithValue(_FakeAuthService()),
          farmRepositoryProvider.overrideWithValue(_FakeFarmRepository()),
          otpServiceProvider.overrideWith((ref) => OtpService(storage.raw)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ramesh Gowda');
    await tester.enterText(fields.at(1), 'new-farmer@farm.org');
    await tester.enterText(fields.at(2), '+919876543210');
    await tester.enterText(fields.at(3), 'Password123');
    await tester.enterText(fields.at(4), 'Password123');
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Verify Phone'), findsOneWidget);
  });
}
