import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_storage_service.dart';
import '../../models/farm/farm_profile_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    FirebaseFirestore.instance,
    ref.watch(localStorageServiceProvider),
  ),
);

class ProfileRepository {
  final FirebaseFirestore firestore;
  final LocalStorageService storage;
  ProfileRepository(this.firestore, this.storage);

  DocumentReference<Map<String, dynamic>> _doc(String userId) => firestore
      .collection('users')
      .doc(userId)
      .collection('profile')
      .doc('current');

  Future<void> save(FarmProfileModel profile) async {
    await _doc(profile.userId).set({
      ...profile.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await storage.raw.setString(
      'phase25_profile_${profile.userId}',
      profile.toJson(),
    );
  }

  String? loadRaw(String userId) =>
      storage.raw.getString('phase25_profile_$userId');

  Future<FarmProfileModel?> load(String userId) async {
    final snapshot = await _doc(userId).get();
    final data = snapshot.data();
    if (data != null) {
      try {
        final normalized = Map<String, dynamic>.from(data);
        normalized.removeWhere((key, value) => value is FieldValue);
        final profile = FarmProfileModel.fromMap(normalized);
        await storage.raw.setString(
          'phase25_profile_$userId',
          profile.toJson(),
        );
        return profile;
      } catch (_) {}
    }
    final raw = loadRaw(userId);
    if (raw == null || raw.isEmpty) return null;
    try {
      return FarmProfileModel.fromJson(raw);
    } catch (_) {
      return null;
    }
  }
}
