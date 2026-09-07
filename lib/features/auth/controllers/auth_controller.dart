import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../repositories/auth/auth_repository.dart';
import '../../../services/auth/auth_service.dart';
import 'auth_state.dart';

// Providers definition
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError(
    'localStorageServiceProvider must be overridden in ProviderScope',
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  final localStorage = ref.watch(localStorageServiceProvider);
  return IsolatedAuthService(localStorage);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final service = ref.watch(authServiceProvider);
  return AuthRepositoryImpl(service);
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final repository = ref.watch(authRepositoryProvider);
    return AuthController(repository);
  },
);

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(AuthState.initial()) {
    checkSession();
  }

  /// Initial check for existing authenticated session
  Future<void> checkSession() async {
    state = AuthState.loading();
    try {
      final user = await _repository.getSavedSession();
      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = AuthState.unauthenticated();
      }
    } catch (e) {
      state = AuthState.unauthenticated();
    }
  }

  /// User Registration
  Future<bool> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    state = AuthState.loading();
    try {
      final user = await _repository.signUp(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );
      state = AuthState.authenticated(user);
      return true;
    } on Failure catch (f) {
      state = AuthState.error(f.message);
      return false;
    } catch (e) {
      state = AuthState.error('Failed to register account: $e');
      return false;
    }
  }

  /// User Login
  Future<bool> login({required String email, required String password}) async {
    state = AuthState.loading();
    try {
      final user = await _repository.login(email: email, password: password);
      state = AuthState.authenticated(user);
      return true;
    } on Failure catch (f) {
      state = AuthState.error(f.message);
      return false;
    } catch (e) {
      state = AuthState.error('Failed to log in: $e');
      return false;
    }
  }

  /// Sign in using the configured Google identity provider.
  Future<bool> signInWithGoogle() async {
    state = AuthState.loading();
    try {
      final user = await _repository.signInWithGoogle();
      state = AuthState.authenticated(user);
      return true;
    } on Failure catch (f) {
      state = AuthState.error(f.message);
      return false;
    } catch (e) {
      state = AuthState.error('Failed to sign in with Google: $e');
      return false;
    }
  }

  /// Password Reset
  Future<bool> sendPasswordResetEmail(String email) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repository.sendPasswordResetEmail(email);
      state = state.copyWith(
        status: state.user != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        successMessage:
            'Password reset link sent to $email. Please check your inbox.',
      );
      return true;
    } on Failure catch (f) {
      state = AuthState.error(f.message);
      return false;
    } catch (e) {
      state = AuthState.error('Could not send password reset email.');
      return false;
    }
  }

  /// Resend Verification Email
  Future<void> resendVerificationEmail() async {
    try {
      await _repository.sendEmailVerification();
      state = state.copyWith(
        successMessage: 'Verification email resent successfully.',
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to resend verification email.',
      );
    }
  }

  /// Logout
  Future<void> logout() async {
    state = AuthState.loading();
    await _repository.logout();
    state = AuthState.unauthenticated();
  }

  void clearMessages() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }
}
