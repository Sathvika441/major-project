import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/failures.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../models/user/user_model.dart';

abstract class AuthService {
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

  Future<UserModel?> getCurrentUser();

  Future<void> logout();
}

/// Isolated Service implementation for Phase 0 & Phase 1.
/// Runs out-of-the-box using isolated local storage without needing immediate cloud credentials.
class IsolatedAuthService implements AuthService {
  final LocalStorageService _storageService;
  static const String _userDbKey = 'isolated_registered_users_db';

  IsolatedAuthService(this._storageService);

  Future<Map<String, Map<String, dynamic>>> _getUsersDb() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userDbKey);
    if (raw == null || raw.isEmpty) {
      // Seed default demo user for instant testing
      final Map<String, Map<String, dynamic>> seedUsers = {
        'farmer@areca.org': {
          'password': 'Password123',
          'user': UserModel(
            uid: 'areca_demo_user_001',
            name: 'Arecanut Farmer',
            email: 'farmer@areca.org',
            phone: '+919876543210',
            isEmailVerified: true,
            createdAt: DateTime.now(),
          ).toMap(),
        },
      };
      await prefs.setString(_userDbKey, json.encode(seedUsers));
      return seedUsers;
    }
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)),
    );
  }

  Future<void> _saveUsersDb(Map<String, Map<String, dynamic>> db) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userDbKey, json.encode(db));
  }

  @override
  Future<UserModel> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    AppLogger.info('Sign up attempt for email: $email', tag: 'AuthService');
    await Future.delayed(
      const Duration(milliseconds: 800),
    ); // Simulate network latency

    final normalizedEmail = email.trim().toLowerCase();
    final db = await _getUsersDb();

    if (db.containsKey(normalizedEmail)) {
      throw AuthFailure.emailAlreadyInUse();
    }

    final newUser = UserModel(
      uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      email: normalizedEmail,
      phone: phone.trim(),
      isEmailVerified: false,
      createdAt: DateTime.now(),
    );

    db[normalizedEmail] = {'password': password, 'user': newUser.toMap()};

    await _saveUsersDb(db);
    await _storageService.saveSession(newUser.uid, newUser.toJson());

    AppLogger.info(
      'User successfully registered: ${newUser.uid}',
      tag: 'AuthService',
    );
    return newUser;
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    AppLogger.info('Login attempt for email: $email', tag: 'AuthService');
    await Future.delayed(const Duration(milliseconds: 600));

    final normalizedEmail = email.trim().toLowerCase();
    final db = await _getUsersDb();

    if (!db.containsKey(normalizedEmail)) {
      throw AuthFailure.userNotFound();
    }

    final userData = db[normalizedEmail]!;
    final storedPassword = userData['password'] as String;

    if (storedPassword != password) {
      throw AuthFailure.invalidCredentials();
    }

    final user = UserModel.fromMap(
      Map<String, dynamic>.from(userData['user'] as Map),
    );
    await _storageService.saveSession(user.uid, user.toJson());

    AppLogger.info(
      'User logged in successfully: ${user.uid}',
      tag: 'AuthService',
    );
    return user;
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    AppLogger.info('Google sign-in attempt', tag: 'AuthService');
    await Future.delayed(const Duration(milliseconds: 600));

    const googleEmail = 'google.farmer@areca.org';
    final db = await _getUsersDb();
    final existingUser = db[googleEmail];
    final user = existingUser == null
        ? UserModel(
            uid: 'google_areca_demo_user',
            name: 'Google Farmer',
            email: googleEmail,
            phone: '',
            isEmailVerified: true,
            createdAt: DateTime.now(),
          )
        : UserModel.fromMap(
            Map<String, dynamic>.from(existingUser['user'] as Map),
          );

    if (existingUser == null) {
      db[googleEmail] = {'password': '', 'user': user.toMap()};
      await _saveUsersDb(db);
    }
    await _storageService.saveSession(user.uid, user.toJson());

    AppLogger.info('Google sign-in completed: ${user.uid}', tag: 'AuthService');
    return user;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    AppLogger.info('Password reset requested for: $email', tag: 'AuthService');
    await Future.delayed(const Duration(milliseconds: 500));

    final normalizedEmail = email.trim().toLowerCase();
    final db = await _getUsersDb();

    if (!db.containsKey(normalizedEmail)) {
      throw AuthFailure.userNotFound();
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    AppLogger.info('Sending verification email', tag: 'AuthService');
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final userJson = _storageService.getSessionUserJson();
    if (userJson != null && userJson.isNotEmpty) {
      try {
        return UserModel.fromJson(userJson);
      } catch (e) {
        AppLogger.error(
          'Failed to parse cached session user',
          tag: 'AuthService',
          error: e,
        );
      }
    }
    return null;
  }

  @override
  Future<void> logout() async {
    AppLogger.info('Logging out active session', tag: 'AuthService');
    await _storageService.clearSession();
  }
}
