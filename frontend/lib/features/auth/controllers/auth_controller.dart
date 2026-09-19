import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../models/farm/farm_profile_model.dart';
import '../../../models/user/user_model.dart';
import '../../../repositories/auth/auth_repository.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/otp/otp_service.dart';
import 'auth_state.dart';

final authServiceProvider = Provider<AuthService>((ref) =>
    FirebaseAuthService(ref.watch(localStorageServiceProvider)));

final authRepositoryProvider = Provider<AuthRepository>((ref) =>
    AuthRepositoryImpl(ref.watch(authServiceProvider)));

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    ref.watch(authRepositoryProvider),
    ref.watch(otpServiceProvider),
    ref.watch(localStorageServiceProvider),
  ),
);

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final OtpService _otpService;
  final LocalStorageService _storage;

  AuthController(this._repository, this._otpService, this._storage)
      : super(AuthState.initial()) {
    checkSession();
  }

  String _otpKeyForUser(UserModel user) {
    final phone = user.phone.trim();
    return phone.isNotEmpty ? phone : 'mock:${user.uid}';
  }

  Future<void> _migrateLegacyOnboarding(String uid) async {
    if (!_storage.hasCompletedOnboarding() || _storage.hasPhaseBMigrated()) {
      return;
    }

    final raw = _storage.raw.getString('phase25_profile_$uid');
    if (raw == null || raw.isEmpty) return;

    try {
      final profile = FarmProfileModel.fromJson(raw);
      final phaseBComplete = profile.landSurveyNumber.trim().isNotEmpty &&
          profile.arecanutCultivationType.trim().isNotEmpty &&
          profile.soilType.trim().isNotEmpty;

      await _storage.setCompletedPhaseA(true);
      await _storage.setCompletedPhaseB(phaseBComplete);
      await _storage.setPhaseBMigrated(true);
    } catch (_) {
      return;
    }
  }

  Future<void> checkSession() async {
    state = AuthState.loading();
    try {
      final user = await _repository.getSavedSession();
      if (user != null && _storage.isAuthenticated()) {
        if (!_storage.isOtpVerified()) {
          state = AuthState.otpVerificationPending(
            user: user,
            phone: _otpKeyForUser(user),
            forPurpose: 'login',
          );
          return;
        }
        await _migrateLegacyOnboarding(user.uid);
        state = AuthState.authenticated(user);
      } else {
        state = AuthState.unauthenticated();
      }
    } catch (_) {
      state = AuthState.unauthenticated();
    }
  }

  Future<bool> signUp({required String name, required String email, required String phone, required String password}) async {
    state = AuthState.loading();
    try {
      final user = await _repository.signUp(name: name, email: email, phone: phone, password: password);
      await _storage.setOtpVerified(false);
      final otpKey = _otpKeyForUser(user);
      await _otpService.generateOtp(otpKey);
      state = AuthState.otpVerificationPending(user: user, phone: otpKey, forPurpose: 'signup');
      return true;
    } on Failure catch (f) {
      state = AuthState.error(f.message);
      return false;
    } catch (e) {
      state = AuthState.error('Failed to register account: $e');
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = AuthState.loading();
    try {
      final user = await _repository.login(email: email, password: password);
      await _storage.setOtpVerified(false);
      final otpKey = _otpKeyForUser(user);
      await _otpService.generateOtp(otpKey);
      state = AuthState.otpVerificationPending(user: user, phone: otpKey, forPurpose: 'login');
      return true;
    } on Failure catch (f) {
      state = AuthState.error(f.message);
      return false;
    } catch (e) {
      state = AuthState.error('Failed to log in: $e');
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = AuthState.loading();
    try {
      final user = await _repository.signInWithGoogle();
      if (user.phone.isNotEmpty) {
        await _storage.setOtpVerified(false);
        final otpKey = _otpKeyForUser(user);
        await _otpService.generateOtp(otpKey);
        state = AuthState.otpVerificationPending(user: user, phone: otpKey, forPurpose: 'login');
      } else {
        await _storage.setOtpVerified(true);
        await _migrateLegacyOnboarding(user.uid);
        state = AuthState.authenticated(user);
      }
      return true;
    } on Failure catch (f) {
      state = AuthState.error(f.message);
      return false;
    } catch (e) {
      state = AuthState.error('Failed to sign in with Google: $e');
      return false;
    }
  }

  Future<String?> sendLoginOtp({String? overridePhone}) async {
    final phone = overridePhone ??
        state.pendingOtpPhone ??
        (state.user == null ? '' : _otpKeyForUser(state.user!));
    if (phone.isEmpty) {
      state = state.copyWith(errorMessage: 'No account available for OTP.');
      return null;
    }
    try {
      final code = await _otpService.generateOtp(phone);
      state = state.copyWith(successMessage: 'OTP sent to $phone.', errorMessage: null);
      return code;
    } on OtpFailure catch (f) {
      state = state.copyWith(errorMessage: f.message, successMessage: null);
      return null;
    }
  }

  Future<bool> verifyOtpAndLogin(String code, {String? overridePhone}) async {
    final phone = overridePhone ??
        state.pendingOtpPhone ??
        (state.user == null ? '' : _otpKeyForUser(state.user!));
    final user = state.user;
    if (user == null) {
      state = AuthState.error('No active session. Please log in again.');
      return false;
    }
    try {
      await _otpService.verifyOtp(phone, code);
      await _storage.setOtpVerified(true);
      final updated = user.copyWith(isPhoneVerified: true);
      await _repository.updateCurrentUser(updated);
      await _migrateLegacyOnboarding(updated.uid);
      state = AuthState.authenticated(updated);
      return true;
    } on OtpFailure catch (f) {
      state = state.copyWith(errorMessage: f.message, successMessage: null);
      return false;
    } on Failure catch (f) {
      state = state.copyWith(errorMessage: f.message, successMessage: null);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'OTP verification failed: $e');
      return false;
    }
  }

  Future<String?> sendPhoneChangeOtp(String newPhone) async {
    try {
      return await _otpService.generateOtp(newPhone.trim());
    } on OtpFailure catch (f) {
      state = state.copyWith(errorMessage: f.message, successMessage: null);
      return null;
    }
  }

  Future<bool> verifyPhoneChangeOtp(String newPhone, String code) async {
    try {
      await _otpService.verifyOtp(newPhone.trim(), code);
      final current = state.user;
      if (current == null) return false;
      final updated = current.copyWith(
        phone: newPhone.trim(),
        isPhoneVerified: true,
        clearPhoneOtp: true,
        updatedAt: DateTime.now(),
      );
      await _repository.updateCurrentUser(updated);
      state = AuthState.authenticated(updated);
      return true;
    } on OtpFailure catch (f) {
      state = state.copyWith(errorMessage: f.message, successMessage: null);
      return false;
    } on Failure catch (f) {
      state = state.copyWith(errorMessage: f.message, successMessage: null);
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Phone change OTP failed: $e');
      return false;
    }
  }

  Duration? canResendOtp() {
    final phone = state.pendingOtpPhone ??
        (state.user == null ? '' : _otpKeyForUser(state.user!));
    return phone.isEmpty ? null : _otpService.canResend(phone);
  }

  bool isOtpLocked() {
    final phone = state.pendingOtpPhone ??
        (state.user == null ? '' : _otpKeyForUser(state.user!));
    return phone.isNotEmpty && _otpService.isLocked(phone);
  }

  Duration? remainingLockout() {
    final phone = state.pendingOtpPhone ??
        (state.user == null ? '' : _otpKeyForUser(state.user!));
    return phone.isEmpty ? null : _otpService.remainingLockout(phone);
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repository.sendPasswordResetEmail(email);
      state = state.copyWith(
        status: state.user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
        successMessage: 'Password reset link sent to $email. Please check your inbox.',
      );
      return true;
    } on Failure catch (f) {
      state = AuthState.error(f.message);
      return false;
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      await _repository.sendEmailVerification();
      state = state.copyWith(successMessage: 'Verification email resent successfully.');
    } catch (_) {
      state = state.copyWith(errorMessage: 'Failed to resend verification email.');
    }
  }

  Future<void> logout() async {
    state = AuthState.loading();

    // Logging out must not erase onboarding progress. Those flags describe
    // the user's completed setup, not the authentication session. Clearing
    // them here caused an existing user to be sent back to onboarding after
    // every subsequent login.
    await _storage.setOtpVerified(false);
    await _repository.logout();

    state = AuthState.unauthenticated();
  }

  void clearMessages() => state = state.copyWith(errorMessage: null, successMessage: null);
}
