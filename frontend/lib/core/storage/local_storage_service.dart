import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../errors/failures.dart';

class LocalStorageKeys {
  static const String sessionUserId = 'session_user_id';
  static const String sessionUserJson = 'session_user_json';
  static const String isAuthenticated = 'is_authenticated';
  static const String hasCompletedOnboarding = 'has_completed_onboarding';
  static const String rememberedEmail = 'remembered_email';
  static const String themeMode = 'app_theme_mode';
  static const String otpVerified = 'otp_verified';
  static const String hasRequestedPermissions = 'has_requested_permissions';
  static const String hasCompletedPhaseA = 'has_completed_phase_a';
  static const String hasCompletedPhaseB = 'has_completed_phase_b';
  static const String phaseBMigrated = 'phase_b_migrated';
  static const String onboardingRequired = 'onboarding_required';
}

/// Service wrapping persistent local storage via SharedPreferences.
class LocalStorageService {
  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  /// Provides direct access for feature repositories that store JSON blobs.
  SharedPreferences get raw => _prefs;

  /// Session Management
  Future<void> saveSession(String userId, String userJson) async {
    try {
      await _prefs.setString(LocalStorageKeys.sessionUserId, userId);
      await _prefs.setString(LocalStorageKeys.sessionUserJson, userJson);
      await _prefs.setBool(LocalStorageKeys.isAuthenticated, true);
    } catch (e) {
      throw const CacheException('Failed to persist user session.');
    }
  }

  String? getSessionUserId() => _prefs.getString(LocalStorageKeys.sessionUserId);

  String? getSessionUserJson() => _prefs.getString(LocalStorageKeys.sessionUserJson);

  bool isAuthenticated() => _prefs.getBool(LocalStorageKeys.isAuthenticated) ?? false;

  Future<void> clearSession() async {
    try {
      await _prefs.remove(LocalStorageKeys.sessionUserId);
      await _prefs.remove(LocalStorageKeys.sessionUserJson);
      await _prefs.setBool(LocalStorageKeys.isAuthenticated, false);
    } catch (e) {
      throw const CacheException('Failed to clear user session.');
    }
  }

  /// Onboarding Status
  bool hasCompletedOnboarding() =>
      _prefs.getBool(LocalStorageKeys.hasCompletedOnboarding) ?? false;

  Future<void> setOnboardingCompleted(bool value) async {
    await _prefs.setBool(LocalStorageKeys.hasCompletedOnboarding, value);
  }

  /// Remember Email
  String? getRememberedEmail() => _prefs.getString(LocalStorageKeys.rememberedEmail);

  Future<void> setRememberedEmail(String email) async {
    await _prefs.setString(LocalStorageKeys.rememberedEmail, email);
  }

  Future<void> clearRememberedEmail() async {
    await _prefs.remove(LocalStorageKeys.rememberedEmail);
  }

  bool isOtpVerified() => _prefs.getBool(LocalStorageKeys.otpVerified) ?? false;

  Future<void> setOtpVerified(bool value) async {
    await _prefs.setBool(LocalStorageKeys.otpVerified, value);
  }

  bool hasRequestedPermissions() =>
      _prefs.getBool(LocalStorageKeys.hasRequestedPermissions) ?? false;

  Future<void> setHasRequestedPermissions(bool value) async {
    await _prefs.setBool(LocalStorageKeys.hasRequestedPermissions, value);
  }

  bool hasCompletedPhaseA() =>
      _prefs.getBool(LocalStorageKeys.hasCompletedPhaseA) ?? false;

  Future<void> setCompletedPhaseA(bool value) async {
    await _prefs.setBool(LocalStorageKeys.hasCompletedPhaseA, value);
  }

  bool hasCompletedPhaseB() =>
      _prefs.getBool(LocalStorageKeys.hasCompletedPhaseB) ?? false;

  Future<void> setCompletedPhaseB(bool value) async {
    await _prefs.setBool(LocalStorageKeys.hasCompletedPhaseB, value);
  }

  bool isOnboardingRequired() =>
      _prefs.getBool(LocalStorageKeys.onboardingRequired) ?? false;

  Future<void> setOnboardingRequired(bool value) async {
    await _prefs.setBool(LocalStorageKeys.onboardingRequired, value);
  }

  bool hasPhaseBMigrated() =>
      _prefs.getBool(LocalStorageKeys.phaseBMigrated) ?? false;

  Future<void> setPhaseBMigrated(bool value) async {
    await _prefs.setBool(LocalStorageKeys.phaseBMigrated, value);
  }
}

/// Provider overridden with the initialized service in main.dart.
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw StateError('LocalStorageService has not been initialized.');
});
