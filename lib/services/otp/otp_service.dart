import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/failures.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';

class OtpService {
  static const int _otpLength = 6;
  static const Duration _otpValidity = Duration(minutes: 15);
  static const Duration _resendCooldown = Duration(seconds: 60);
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 5);

  static const String _otpPrefix = 'otp_';
  static const String _hashSuffix = '_hash';
  static const String _nonceSuffix = '_nonce';
  static const String _phoneSuffix = '_phone';
  static const String _generatedAtSuffix = '_generated_at';
  static const String _attemptsSuffix = '_attempts';
  static const String _lockoutUntilSuffix = '_lockout_until';
  static const String _lastResendSuffix = '_last_resend';

  final SharedPreferences _prefs;
  final Random _random = Random.secure();

  OtpService(this._prefs);

  String _key(String phone, String suffix) => '$_otpPrefix$phone$suffix';

  String _generateNonce() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _generateCode() {
    final sb = StringBuffer();
    for (int i = 0; i < _otpLength; i++) {
      sb.write(_random.nextInt(10));
    }
    return sb.toString();
  }

  String _hashCode(String code, String phone, String nonce) {
    final bytes = utf8.encode('$code|$phone|$nonce');
    return sha256.convert(bytes).toString();
  }

  Future<String> generateOtp(String phone) async {
    final normalizedPhone = phone.trim();

    final lastResend = _prefs.getInt(_key(normalizedPhone, _lastResendSuffix));
    if (lastResend != null) {
      final lastResendTime = DateTime.fromMillisecondsSinceEpoch(lastResend);
      final elapsed = DateTime.now().difference(lastResendTime);
      if (elapsed < _resendCooldown) {
        final remaining = _resendCooldown - elapsed;
        throw OtpFailure.rateLimited(remaining);
      }
    }

    if (isLocked(normalizedPhone)) {
      final lockoutUntil = _prefs.getInt(_key(normalizedPhone, _lockoutUntilSuffix));
      if (lockoutUntil != null) {
        final remaining =
            DateTime.fromMillisecondsSinceEpoch(lockoutUntil).difference(DateTime.now());
        if (remaining.isNegative == false) {
          throw OtpFailure.tooManyAttempts(remaining);
        }
      }
      _prefs.setInt(_key(normalizedPhone, _attemptsSuffix), 0);
      _prefs.remove(_key(normalizedPhone, _lockoutUntilSuffix));
    }

    final code = _generateCode();
    final nonce = _generateNonce();
    final hash = _hashCode(code, normalizedPhone, nonce);

    final now = DateTime.now();
    await _prefs.setString(_key(normalizedPhone, _hashSuffix), hash);
    await _prefs.setString(_key(normalizedPhone, _nonceSuffix), nonce);
    await _prefs.setString(_key(normalizedPhone, _phoneSuffix), normalizedPhone);
    await _prefs.setInt(
        _key(normalizedPhone, _generatedAtSuffix), now.millisecondsSinceEpoch);
    await _prefs.setInt(_key(normalizedPhone, _attemptsSuffix), 0);
    await _prefs.setInt(
        _key(normalizedPhone, _lastResendSuffix), now.millisecondsSinceEpoch);

    AppLogger.info(
      '[MOCK ENCRYPTED SMS] OTP for $normalizedPhone: $code (valid for 15 min)',
      tag: 'OtpService',
    );
    AppLogger.info(
      '[STORED HASH] SHA-256: ${hash.substring(0, 16)}... (OTP never stored plaintext)',
      tag: 'OtpService',
    );

    return code;
  }

  Future<bool> verifyOtp(String phone, String code) async {
    final normalizedPhone = phone.trim();
    final trimmedCode = code.trim();

    if (isLocked(normalizedPhone)) {
      final lockoutUntil = _prefs.getInt(_key(normalizedPhone, _lockoutUntilSuffix));
      if (lockoutUntil != null) {
        final remaining =
            DateTime.fromMillisecondsSinceEpoch(lockoutUntil).difference(DateTime.now());
        if (remaining.isNegative == false) {
          throw OtpFailure.tooManyAttempts(remaining);
        }
      }
      _prefs.setInt(_key(normalizedPhone, _attemptsSuffix), 0);
      _prefs.remove(_key(normalizedPhone, _lockoutUntilSuffix));
    }

    final storedPhone = _prefs.getString(_key(normalizedPhone, _phoneSuffix));
    if (storedPhone == null) {
      throw OtpFailure.notFound();
    }
    if (storedPhone != normalizedPhone) {
      throw OtpFailure.phoneMismatch();
    }

    final generatedAt = _prefs.getInt(_key(normalizedPhone, _generatedAtSuffix));
    if (generatedAt == null) {
      throw OtpFailure.notFound();
    }
    final generatedTime = DateTime.fromMillisecondsSinceEpoch(generatedAt);
    final age = DateTime.now().difference(generatedTime);
    if (age > _otpValidity) {
      _clearOtpState(normalizedPhone);
      throw OtpFailure.expired();
    }

    final storedHash = _prefs.getString(_key(normalizedPhone, _hashSuffix));
    final storedNonce = _prefs.getString(_key(normalizedPhone, _nonceSuffix));
    final attemptCount = _prefs.getInt(_key(normalizedPhone, _attemptsSuffix)) ?? 0;

    if (storedHash == null || storedNonce == null) {
      throw OtpFailure.notFound();
    }

    final providedHash = _hashCode(trimmedCode, normalizedPhone, storedNonce);

    if (providedHash == storedHash) {
      _clearOtpState(normalizedPhone);
      return true;
    } else {
      final newAttempts = attemptCount + 1;
      await _prefs.setInt(_key(normalizedPhone, _attemptsSuffix), newAttempts);

      if (newAttempts >= _maxAttempts) {
        final lockoutUntil =
            DateTime.now().add(_lockoutDuration).millisecondsSinceEpoch;
        await _prefs.setInt(_key(normalizedPhone, _lockoutUntilSuffix), lockoutUntil);
        throw OtpFailure.tooManyAttempts(_lockoutDuration);
      }

      throw OtpFailure.invalidOtp();
    }
  }

  Duration? canResend(String phone) {
    final normalizedPhone = phone.trim();
    final lastResend = _prefs.getInt(_key(normalizedPhone, _lastResendSuffix));
    if (lastResend == null) return null;

    final lastResendTime = DateTime.fromMillisecondsSinceEpoch(lastResend);
    final elapsed = DateTime.now().difference(lastResendTime);
    if (elapsed < _resendCooldown) {
      return _resendCooldown - elapsed;
    }
    return null;
  }

  bool isLocked(String phone) {
    final normalizedPhone = phone.trim();
    final lockoutUntil = _prefs.getInt(_key(normalizedPhone, _lockoutUntilSuffix));
    if (lockoutUntil == null) return false;

    final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutUntil);
    return lockoutTime.isAfter(DateTime.now());
  }

  Duration? remainingLockout(String phone) {
    final normalizedPhone = phone.trim();
    final lockoutUntil = _prefs.getInt(_key(normalizedPhone, _lockoutUntilSuffix));
    if (lockoutUntil == null) return null;

    final remaining =
        DateTime.fromMillisecondsSinceEpoch(lockoutUntil).difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  void _clearOtpState(String phone) {
    final normalizedPhone = phone.trim();
    _prefs.remove(_key(normalizedPhone, _hashSuffix));
    _prefs.remove(_key(normalizedPhone, _nonceSuffix));
    _prefs.remove(_key(normalizedPhone, _phoneSuffix));
    _prefs.remove(_key(normalizedPhone, _generatedAtSuffix));
    _prefs.remove(_key(normalizedPhone, _attemptsSuffix));
    _prefs.remove(_key(normalizedPhone, _lockoutUntilSuffix));
    _prefs.remove(_key(normalizedPhone, _lastResendSuffix));
  }
}

final otpServiceProvider = Provider<OtpService>((ref) {
  final localStorage = ref.watch(localStorageServiceProvider);
  return OtpService(localStorage.raw);
});
