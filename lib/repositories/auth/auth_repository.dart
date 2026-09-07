import '../../core/errors/failures.dart';
import '../../core/utils/app_logger.dart';
import '../../models/user/user_model.dart';
import '../../services/auth/auth_service.dart';

abstract class AuthRepository {
  Future<UserModel> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  });

  Future<UserModel> login({required String email, required String password});

  Future<UserModel> signInWithGoogle();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> sendEmailVerification();

  Future<UserModel?> getSavedSession();

  Future<void> logout();
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;

  AuthRepositoryImpl(this._authService);

  @override
  Future<UserModel> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      return await _authService.signUp(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );
    } on Failure {
      rethrow;
    } catch (e, stack) {
      AppLogger.error(
        'Unexpected error during signup',
        error: e,
        stackTrace: stack,
      );
      throw ServerFailure('Failed to complete registration. ${e.toString()}');
    }
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _authService.login(email: email, password: password);
    } on Failure {
      rethrow;
    } catch (e, stack) {
      AppLogger.error(
        'Unexpected error during login',
        error: e,
        stackTrace: stack,
      );
      throw ServerFailure('Failed to log in. ${e.toString()}');
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      return await _authService.signInWithGoogle();
    } on Failure {
      rethrow;
    } catch (e, stack) {
      AppLogger.error(
        'Unexpected error during Google sign-in',
        error: e,
        stackTrace: stack,
      );
      throw ServerFailure('Failed to sign in with Google. ${e.toString()}');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
    } on Failure {
      rethrow;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to send password reset email',
        error: e,
        stackTrace: stack,
      );
      throw ServerFailure('Unable to send password reset email.');
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
    } on Failure {
      rethrow;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to send verification email',
        error: e,
        stackTrace: stack,
      );
      throw ServerFailure('Unable to send verification email.');
    }
  }

  @override
  Future<UserModel?> getSavedSession() async {
    try {
      return await _authService.getCurrentUser();
    } catch (e) {
      AppLogger.warning('Error fetching saved session: $e');
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (e) {
      AppLogger.error('Error during logout', error: e);
    }
  }
}
