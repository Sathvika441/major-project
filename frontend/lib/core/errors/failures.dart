import 'package:flutter/foundation.dart';

/// Base class for all domain failures in the application.
@immutable
abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  String toString() => '$runtimeType: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Authentication specific failures (invalid credentials, user disabled, email in use, etc.)
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});

  factory AuthFailure.invalidCredentials() =>
      const AuthFailure('Invalid email or password. Please try again.', code: 'INVALID_CREDENTIALS');

  factory AuthFailure.emailAlreadyInUse() =>
      const AuthFailure('An account already exists with this email address.', code: 'EMAIL_IN_USE');

  factory AuthFailure.userNotFound() =>
      const AuthFailure('No account found with this email address.', code: 'USER_NOT_FOUND');

  factory AuthFailure.weakPassword() =>
      const AuthFailure('The password provided is too weak. Please use at least 8 characters with numbers and symbols.', code: 'WEAK_PASSWORD');

  factory AuthFailure.userDisabled() =>
      const AuthFailure('This account has been disabled. Please contact support.', code: 'USER_DISABLED');

  factory AuthFailure.requiresVerification() =>
      const AuthFailure('Please verify your email address before logging in.', code: 'EMAIL_NOT_VERIFIED');
}

/// OTP verification specific failures
class OtpFailure extends Failure {
  const OtpFailure(super.message, {super.code});

  factory OtpFailure.invalidOtp() =>
      const OtpFailure('Invalid OTP. Please check and try again.', code: 'OTP_INVALID');

  factory OtpFailure.expired() =>
      const OtpFailure('OTP has expired. Please request a new one.', code: 'OTP_EXPIRED');

  factory OtpFailure.rateLimited(Duration cooldown) =>
      OtpFailure('Too many requests. Please wait ${cooldown.inSeconds}s before requesting a new OTP.', code: 'OTP_RATE_LIMITED');

  factory OtpFailure.tooManyAttempts(Duration lockout) =>
      OtpFailure('Too many failed attempts. Please try again after ${lockout.inMinutes} minute(s).', code: 'OTP_LOCKED');

  factory OtpFailure.phoneMismatch() =>
      const OtpFailure('Phone number does not match the OTP session.', code: 'OTP_PHONE_MISMATCH');

  factory OtpFailure.notFound() =>
      const OtpFailure('No active OTP session found. Request a new OTP.', code: 'OTP_NOT_FOUND');
}

/// Network connectivity failures
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network connection unavailable. Please check your internet connection.'])
      : super(code: 'NETWORK_ERROR');
}

/// Storage and caching failures
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Failed to read or write local session storage.'])
      : super(code: 'CACHE_ERROR');
}

/// Data validation failures
class ValidationFailure extends Failure {
  const ValidationFailure(super.message) : super(code: 'VALIDATION_ERROR');
}

/// General unexpected server failures
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'An unexpected server error occurred. Please try again later.'])
      : super(code: 'SERVER_ERROR');
}

/// Custom Exception types to bridge raw service errors to Failures
class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => message;
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'No network connection available.'])
      : super(code: 'NETWORK_DISCONNECTED');
}

class CacheException extends AppException {
  const CacheException([super.message = 'Local cache access error.'])
      : super(code: 'CACHE_ACCESS_FAILED');
}
