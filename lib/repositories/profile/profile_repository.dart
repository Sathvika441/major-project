import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/local_storage_service.dart';
import '../../models/farm/farm_profile_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) =>
    ProfileRepository(ref.watch(localStorageServiceProvider)));

class ProfileRepository {
  final LocalStorageService storage;
  ProfileRepository(this.storage);

  String _key(String userId) => 'phase25_profile_$userId';

  Future<void> save(FarmProfileModel profile) =>
      storage.raw.setString(_key(profile.userId), profile.toJson());

  String? loadRaw(String userId) => storage.raw.getString(_key(userId));
}
