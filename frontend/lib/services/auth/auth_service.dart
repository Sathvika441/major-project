import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../models/user/user_model.dart';

abstract class AuthService {
  Future<UserModel> signUp({required String name, required String email, required String phone, required String password});
  Future<UserModel> login({required String email, required String password});
  Future<UserModel> signInWithGoogle();
  Future<void> updateCurrentUser(UserModel user);
  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification();
  Future<UserModel?> getCurrentUser();
  Future<void> logout();
}

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final LocalStorageService _storage;

  FirebaseAuthService(this._storage, {FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<UserModel> _userModel(User user, {String? name, String? phone}) async {
    final doc = await _users.doc(user.uid).get();
    final data = doc.data() ?? <String, dynamic>{};
    final created = _readDateTime(data['createdAt']) ?? DateTime.now();
    final model = UserModel(
      uid: user.uid,
      name: name ?? (data['name'] as String? ?? user.displayName ?? ''),
      email: user.email ?? (data['email'] as String? ?? ''),
      phone: phone ?? (data['phone'] as String? ?? user.phoneNumber ?? ''),
      isEmailVerified: user.emailVerified,
      isPhoneVerified: (data['isPhoneVerified'] as bool?) ?? user.phoneNumber != null,
      termsAccepted: (data['termsAccepted'] as bool?) ?? true,
      createdAt: created,
      updatedAt: DateTime.now(),
    );
    await _users.doc(user.uid).set({
      ...model.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _storage.saveSession(model.uid, model.toJson());
    return model;
  }

  @override
  Future<UserModel> signUp({required String name, required String email, required String phone, required String password}) async {
    AppLogger.info('Firebase signup: $email', tag: 'AuthService');
    final credential = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = credential.user!;
    await user.updateDisplayName(name.trim());
    await user.sendEmailVerification();
    try {
      return await _userModel(user, name: name.trim(), phone: phone.trim());
    } on FirebaseException catch (e) {
      AppLogger.error(
        'Firebase Auth signup succeeded, but Firestore profile write/read failed',
        tag: 'AuthService',
        error: e,
      );
      // Authentication is already complete; keep a local session so the user
      // can continue while Firestore connectivity/rules are repaired.
      final fallback = UserModel(
        uid: user.uid,
        name: name.trim(),
        email: user.email ?? email.trim(),
        phone: phone.trim(),
        isEmailVerified: user.emailVerified,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _storage.saveSession(fallback.uid, fallback.toJson());
      return fallback;
    }
  }

  @override
  Future<UserModel> login({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    return _userModel(credential.user!);
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    if (!kIsWeb) {
      throw UnsupportedError(
        'Google sign-in is currently configured for the web build. '
        'Native Google sign-in requires the platform Google Sign-In configuration.',
      );
    }

    AppLogger.info('Starting Google sign-in popup', tag: 'AuthService');
    final provider = GoogleAuthProvider();
    provider.addScope('email');
    provider.setCustomParameters({
      'prompt': 'select_account',
    });

    final credential = await _auth.signInWithPopup(provider);
    final user = credential.user;
    if (user == null) {
      throw StateError('Google sign-in completed without a Firebase user.');
    }

    return _userModel(user);
  }

  @override
  Future<void> updateCurrentUser(UserModel user) async {
    final current = _auth.currentUser;
    if (current == null || current.uid != user.uid) throw StateError('No matching Firebase session.');
    if (current.email != user.email) await current.verifyBeforeUpdateEmail(user.email);
    await current.updateDisplayName(user.name);
    await _users.doc(user.uid).set({
      ...user.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _storage.saveSession(user.uid, user.toJson());
  }

  @override
  Future<void> sendPasswordResetEmail(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed-in Firebase user.');
    await user.sendEmailVerification();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      await _storage.clearSession();
      return null;
    }
    return _userModel(user);
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
    await _storage.clearSession();
  }
}


/// In-memory/local implementation used by isolated unit tests.
@visibleForTesting
class IsolatedAuthService implements AuthService {
  static const _usersKey = 'isolated_auth_users';
  final LocalStorageService _storage;
  IsolatedAuthService(this._storage);

  Map<String, String> _users() {
    final raw = _storage.raw.getStringList(_usersKey) ?? <String>[];
    final users = <String, String>{};
    for (final entry in raw) {
      final separator = entry.indexOf('|');
      if (separator <= 0) continue;
      users[entry.substring(0, separator)] = entry.substring(separator + 1);
    }
    return users;
  }

  Future<void> _saveUsers(Map<String, String> users) async {
    await _storage.raw.setStringList(
      _usersKey,
      users.entries.map((entry) => entry.key + '|' + entry.value).toList(),
    );
  }

  @override
  Future<UserModel> signUp({required String name, required String email, required String phone, required String password}) async {
    if (password.length < 8) throw AuthFailure.weakPassword();
    final normalizedEmail = email.trim().toLowerCase();
    final users = _users();
    if (users.containsKey(normalizedEmail)) throw AuthFailure.emailAlreadyInUse();
    final now = DateTime.now();
    final user = UserModel(
      uid: 'isolated-' + normalizedEmail.hashCode.abs().toString(),
      name: name.trim(),
      email: normalizedEmail,
      phone: phone.trim(),
      createdAt: now,
      updatedAt: now,
    );
    users[normalizedEmail] = user.toJson();
    await _saveUsers(users);
    await _storage.saveSession(user.uid, user.toJson());
    return user;
  }

  @override
  Future<UserModel> login({required String email, required String password}) async {
    final userJson = _users()[email.trim().toLowerCase()];
    if (userJson == null) throw AuthFailure.userNotFound();
    final user = UserModel.fromJson(userJson);
    await _storage.saveSession(user.uid, user.toJson());
    return user;
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    final now = DateTime.now();
    final user = UserModel(
      uid: 'isolated-google-user',
      name: 'Google Farmer',
      email: 'google.farmer@areca.org',
      phone: '',
      isEmailVerified: true,
      createdAt: now,
      updatedAt: now,
    );
    final users = _users();
    users[user.email] = user.toJson();
    await _saveUsers(users);
    await _storage.saveSession(user.uid, user.toJson());
    return user;
  }

  @override
  Future<void> updateCurrentUser(UserModel user) async {
    final currentUid = _storage.getSessionUserId();
    if (currentUid != user.uid) throw StateError('No matching isolated auth session.');
    final users = _users();
    users[user.email] = user.toJson();
    await _saveUsers(users);
    await _storage.saveSession(user.uid, user.toJson());
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<UserModel?> getCurrentUser() async {
    final json = _storage.getSessionUserJson();
    return json == null ? null : UserModel.fromJson(json);
  }

  @override
  Future<void> logout() => _storage.clearSession();
}
