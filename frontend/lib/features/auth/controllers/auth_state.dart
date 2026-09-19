import 'package:flutter/foundation.dart';
import '../../../models/user/user_model.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  emailVerificationPending,
  otpVerificationPending,
  error,
}

@immutable
class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;
  final String? successMessage;
  final String? pendingOtpPhone;
  final String? pendingOtpFor;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.successMessage,
    this.pendingOtpPhone,
    this.pendingOtpFor,
  });

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);
  factory AuthState.loading() => const AuthState(status: AuthStatus.loading);
  factory AuthState.authenticated(UserModel user) =>
      AuthState(status: AuthStatus.authenticated, user: user);
  factory AuthState.unauthenticated([String? message]) =>
      AuthState(status: AuthStatus.unauthenticated, errorMessage: message);
  factory AuthState.emailVerificationPending(UserModel user) =>
      AuthState(status: AuthStatus.emailVerificationPending, user: user);
  factory AuthState.otpVerificationPending({
    required UserModel user,
    required String phone,
    String forPurpose = 'login',
  }) =>
      AuthState(
        status: AuthStatus.otpVerificationPending,
        user: user,
        pendingOtpPhone: phone,
        pendingOtpFor: forPurpose,
      );
  factory AuthState.error(String message) =>
      AuthState(status: AuthStatus.error, errorMessage: message);

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
    String? successMessage,
    String? pendingOtpPhone,
    String? pendingOtpFor,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      successMessage: successMessage,
      pendingOtpPhone: pendingOtpPhone ?? this.pendingOtpPhone,
      pendingOtpFor: pendingOtpFor ?? this.pendingOtpFor,
    );
  }
}
