import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:major_proj_1/app/theme/theme_mode_controller.dart';
import 'package:major_proj_1/core/storage/local_storage_service.dart';
import 'package:major_proj_1/features/auth/controllers/auth_controller.dart';
import 'package:major_proj_1/features/auth/screens/signup_screen.dart';
import 'package:major_proj_1/models/farm/farm_model.dart';
import 'package:major_proj_1/models/user/user_model.dart';
import 'package:major_proj_1/repositories/auth/auth_repository.dart';
import 'package:major_proj_1/repositories/farm/farm_repository.dart';
import 'package:major_proj_1/services/otp/otp_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('sign-up screen displays registration form', (tester) async {
    await _pumpSignupScreen(tester);

    expect(find.text('Join ArecaSmart'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(5));
    expect(find.text('Create account'), findsOneWidget);
    expect(
      find.text(
        'I agree to the Terms of Service and Privacy Policy for agricultural data usage.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('registration form validates required fields', (tester) async {
    await _pumpSignupScreen(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
  });
}

Future<void> _pumpSignupScreen(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await LocalStorageService.init();
  final router = GoRouter(
    initialLocation: '/signup',
    routes: [
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
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
        themeModeProvider.overrideWith(
          (ref) => ThemeModeController(ref.watch(localStorageServiceProvider)),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
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
