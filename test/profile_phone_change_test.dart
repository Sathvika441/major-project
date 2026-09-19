import 'package:flutter_test/flutter_test.dart';
import 'package:major_proj_1/core/storage/local_storage_service.dart';
import 'package:major_proj_1/services/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('updated phone is persisted and marked verified', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.init();
    final auth = IsolatedAuthService(storage);

    final created = await auth.signUp(
      name: 'Test Farmer',
      email: 'phone-change@test.local',
      phone: '+919876543210',
      password: 'Password123',
    );
    final updated = created.copyWith(
      phone: '+919812345678',
      isPhoneVerified: true,
      updatedAt: DateTime.now(),
    );

    await auth.updateCurrentUser(updated);
    final restored = await auth.getCurrentUser();

    expect(restored?.phone, '+919812345678');
    expect(restored?.isPhoneVerified, isTrue);
  });
}

