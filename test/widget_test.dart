import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:major_proj_1/core/storage/local_storage_service.dart';
import 'package:major_proj_1/features/auth/controllers/auth_controller.dart';
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

    // Initial frame pumps splash screen
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
        ],
        child: const ArecaSmartApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sign Up'));
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Register Account'), findsOneWidget);
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
        ],
        child: const ArecaSmartApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.textContaining('Welcome, Google Farmer!'), findsOneWidget);
  });
}
