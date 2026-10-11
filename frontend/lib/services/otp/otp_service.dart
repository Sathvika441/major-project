import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/failures.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';

class OtpService {
  static const Duration _otpValidity = Duration(minutes: 15);
  static const Duration _resendCooldown = Duration(seconds: 2);
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 5);

  final SharedPreferences _prefs;
  final Random _random = Random.secure();

  OtpService(this._prefs);

  String _key(String phone, String suffix) => 'otp_${phone.trim()}$suffix';

  String _hashCode(String code, String phone, String nonce) =>
      sha256.convert(utf8.encode('$code|$phone|$nonce')).toString();

  String _generateCode() => List.generate(6, (_) => _random.nextInt(10)).join();

  String _generateNonce() =>
      base64Url.encode(List<int>.generate(16, (_) => _random.nextInt(256)));

  Future<String> generateOtp(String phone) async {
    final normalized = phone.trim();
    final last = _prefs.getInt(_key(normalized, '_last_resend'));
    if (last != null) {
      final elapsed = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(last),
      );
      if (elapsed < _resendCooldown) {
        throw OtpFailure.rateLimited(_resendCooldown - elapsed);
      }
    }
    if (isLocked(normalized)) {
      throw OtpFailure.tooManyAttempts(
        remainingLockout(normalized) ?? _lockoutDuration,
      );
    }

    final code = _generateCode();
    final nonce = _generateNonce();
    final now = DateTime.now();
    await _prefs.setString(
      _key(normalized, '_hash'),
      _hashCode(code, normalized, nonce),
    );
    await _prefs.setString(_key(normalized, '_nonce'), nonce);
    await _prefs.setString(_key(normalized, '_phone'), normalized);
    await _prefs.setInt(
      _key(normalized, '_generated_at'),
      now.millisecondsSinceEpoch,
    );
    await _prefs.setInt(_key(normalized, '_attempts'), 0);
    await _prefs.setInt(
      _key(normalized, '_last_resend'),
      now.millisecondsSinceEpoch,
    );

    AppLogger.info(
      '[MOCK ENCRYPTED SMS] OTP for $normalized: $code (valid for 15 min)',
      tag: 'OtpService',
    );
    return code;
  }

  Future<bool> verifyOtp(String phone, String code) async {
    final normalized = phone.trim();
    if (isLocked(normalized)) {
      throw OtpFailure.tooManyAttempts(
        remainingLockout(normalized) ?? _lockoutDuration,
      );
    }

    final storedPhone = _prefs.getString(_key(normalized, '_phone'));
    if (storedPhone == null) throw OtpFailure.notFound();
    if (storedPhone != normalized) throw OtpFailure.phoneMismatch();

    final generatedAt = _prefs.getInt(_key(normalized, '_generated_at'));
    if (generatedAt == null) throw OtpFailure.notFound();
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(generatedAt),
    );
    if (age > _otpValidity) {
      _clearVerificationState(normalized);
      throw OtpFailure.expired();
    }

    final storedHash = _prefs.getString(_key(normalized, '_hash'));
    final nonce = _prefs.getString(_key(normalized, '_nonce'));
    if (storedHash == null || nonce == null) throw OtpFailure.notFound();

    if (_hashCode(code.trim(), normalized, nonce) == storedHash) {
      _clearVerificationState(normalized);
      return true;
    }

    final attempts = (_prefs.getInt(_key(normalized, '_attempts')) ?? 0) + 1;
    await _prefs.setInt(_key(normalized, '_attempts'), attempts);
    if (attempts >= _maxAttempts) {
      await _prefs.setInt(
        _key(normalized, '_lockout_until'),
        DateTime.now().add(_lockoutDuration).millisecondsSinceEpoch,
      );
      throw OtpFailure.tooManyAttempts(_lockoutDuration);
    }
    throw OtpFailure.invalidOtp();
  }

  Duration? canResend(String phone) {
    final last = _prefs.getInt(_key(phone, '_last_resend'));
    if (last == null) return null;
    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(last),
    );
    return elapsed < _resendCooldown ? _resendCooldown - elapsed : null;
  }

  bool isLocked(String phone) {
    final until = _prefs.getInt(_key(phone, '_lockout_until'));
    return until != null &&
        DateTime.fromMillisecondsSinceEpoch(until).isAfter(DateTime.now());
  }

  Duration? remainingLockout(String phone) {
    final until = _prefs.getInt(_key(phone, '_lockout_until'));
    if (until == null) return null;
    final remaining = DateTime.fromMillisecondsSinceEpoch(until)
        .difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  void _clearVerificationState(String phone) {
    for (final suffix in <String>[
      '_hash',
      '_nonce',
      '_phone',
      '_generated_at',
      '_attempts',
      '_lockout_until',
    ]) {
      _prefs.remove(_key(phone, suffix));
    }
  }
}

final otpServiceProvider = Provider<OtpService>((ref) {
  return OtpService(ref.watch(localStorageServiceProvider).raw);
});
