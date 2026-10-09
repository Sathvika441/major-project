import 'package:flutter_test/flutter_test.dart';
import 'package:major_proj_1/core/errors/failures.dart';
import 'package:major_proj_1/core/storage/local_storage_service.dart';
import 'package:major_proj_1/services/auth/auth_service.dart' hide AuthFailure;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late IsolatedAuthService authService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.init();
    authService = IsolatedAuthService(storage);
  });

  test('sign up creates an account and saves the active session', () async {
    final user = await authService.signUp(
      name: 'Ramesh Gowda',
      email: 'ramesh@farm.org',
      phone: '+919876543210',
      password: 'Password123',
    );

    expect(user.name, 'Ramesh Gowda');
    expect(user.email, 'ramesh@farm.org');
    expect((await authService.getCurrentUser())?.uid, user.uid);
  });

  test('sign up rejects an email that is already registered', () async {
    const email = 'ramesh@farm.org';

    await authService.signUp(
      name: 'Ramesh Gowda',
      email: email,
      phone: '+919876543210',
      password: 'Password123',
    );

    expect(
      () => authService.signUp(
        name: 'Another Farmer',
        email: email.toUpperCase(),
        phone: '+919876543211',
        password: 'Password123',
      ),
      throwsA(isA<AuthFailure>()),
    );
  });

  test('Google sign-in creates and saves a verified user session', () async {
    final user = await authService.signInWithGoogle();

    expect(user.email, 'google.farmer@areca.org');
    expect(user.isEmailVerified, isTrue);
    expect((await authService.getCurrentUser())?.uid, user.uid);
  });
}
