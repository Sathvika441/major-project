import 'package:flutter_test/flutter_test.dart';
import 'package:major_proj_1/core/storage/local_storage_service.dart';
import 'package:major_proj_1/services/otp/otp_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late OtpService service;
  late LocalStorageService storage;
  const phone = '+919876543210';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    service = OtpService(storage.raw);
  });

  test('generates a 6 digit numeric OTP', () async {
    final otp = await service.generateOtp(phone);
    expect(otp, matches(RegExp(r'^\d{6}$')));
  });

  test('OTP hash is stored, not plaintext', () async {
    final otp = await service.generateOtp(phone);
    final storedHash = storage.raw.getString('otp_${phone}_hash');
    expect(storedHash, isNotNull);
    expect(storedHash, isNot(otp));
    expect(storedHash, hasLength(64));
  });

  test('resend is rate limited for 60 seconds', () async {
    await service.generateOtp(phone);
    expect(() => service.generateOtp(phone), throwsA(isA<OtpFailure>()));
    expect(service.canResend(phone), isNotNull);
  });

  test('five wrong OTP attempts lock the phone', () async {
    await service.generateOtp(phone);
    for (var i = 0; i < 5; i++) {
      await expectLater(
        service.verifyOtp(phone, '000000'),
        throwsA(isA<OtpFailure>()),
      );
    }
    expect(service.isLocked(phone), isTrue);
  });

  test('expired OTP is rejected', () async {
    await service.generateOtp(phone);
    await storage.raw.setInt(
      'otp_${phone}_generated_at',
      DateTime.now().subtract(const Duration(minutes: 16)).millisecondsSinceEpoch,
    );
    await expectLater(
      service.verifyOtp(phone, '000000'),
      throwsA(isA<OtpFailure>()),
    );
  });
}
