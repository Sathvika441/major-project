import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:major_proj_1/core/storage/local_storage_service.dart';
import 'package:major_proj_1/features/auth/controllers/auth_controller.dart';
import 'package:major_proj_1/features/auth/screens/signup_screen.dart';
import 'package:major_proj_1/services/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('registration button creates an account and opens dashboard', (
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
          path: '/dashboard',
          builder: (context, state) => const Text('Dashboard'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ramesh Gowda');
    await tester.enterText(fields.at(1), 'new-farmer@farm.org');
    await tester.enterText(fields.at(2), '+919876543210');
    await tester.enterText(fields.at(3), 'Password123');
    await tester.enterText(fields.at(4), 'Password123');
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.text('Register Account'));
    await tester.tap(find.text('Register Account'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Dashboard'), findsOneWidget);
  });
}
