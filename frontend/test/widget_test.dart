import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:major_proj_1/app/theme/theme_mode_controller.dart';
import 'package:major_proj_1/core/storage/local_storage_service.dart';
import 'package:major_proj_1/features/auth/controllers/auth_controller.dart';
import 'package:major_proj_1/features/auth/controllers/auth_state.dart';
import 'package:major_proj_1/features/auth/screens/login_screen.dart';
import 'package:major_proj_1/main.dart';
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
    SharedPreferences.setMockInitialValues({});
    final localStorage = await LocalStorageService.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(localStorage),
          authControllerProvider.overrideWithValue(AuthState.unauthenticated()),
          themeModeProvider.overrideWithValue(ThemeMode.dark),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('login screen offers Google sign-in', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final localStorage = await LocalStorageService.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(localStorage),
          authControllerProvider.overrideWithValue(AuthState.unauthenticated()),
          themeModeProvider.overrideWithValue(ThemeMode.dark),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
