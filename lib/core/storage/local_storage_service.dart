import 'package:shared_preferences/shared_preferences.dart';
import '../errors/failures.dart';

class LocalStorageKeys {
  static const String sessionUserId = 'session_user_id';
  static const String sessionUserJson = 'session_user_json';
  static const String isAuthenticated = 'is_authenticated';
  static const String hasCompletedOnboarding = 'has_completed_onboarding';
  static const String rememberedEmail = 'remembered_email';
  static const String themeMode = 'app_theme_mode';
}

/// Service wrapping persistent local storage via SharedPreferences.
class LocalStorageService {
  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

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

  String? getSessionUserId() {
    return _prefs.getString(LocalStorageKeys.sessionUserId);
  }

  String? getSessionUserJson() {
    return _prefs.getString(LocalStorageKeys.sessionUserJson);
  }

  bool isAuthenticated() {
    return _prefs.getBool(LocalStorageKeys.isAuthenticated) ?? false;
  }

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
  bool hasCompletedOnboarding() {
    return _prefs.getBool(LocalStorageKeys.hasCompletedOnboarding) ?? false;
  }

  Future<void> setOnboardingCompleted(bool value) async {
    await _prefs.setBool(LocalStorageKeys.hasCompletedOnboarding, value);
  }

  /// Remember Email
  String? getRememberedEmail() {
    return _prefs.getString(LocalStorageKeys.rememberedEmail);
  }

  Future<void> setRememberedEmail(String email) async {
    await _prefs.setString(LocalStorageKeys.rememberedEmail, email);
  }

  Future<void> clearRememberedEmail() async {
    await _prefs.remove(LocalStorageKeys.rememberedEmail);
  }
}
