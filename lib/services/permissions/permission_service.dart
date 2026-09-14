import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/storage/local_storage_service.dart';

class PermissionResult {
  final PermissionStatus camera;
  final PermissionStatus gallery;

  const PermissionResult({required this.camera, required this.gallery});

  bool get allGranted =>
      camera.isGranted || camera.isLimited ?
      (gallery.isGranted || gallery.isLimited) : false;

  bool get anyPermanentlyDenied =>
      camera.isPermanentlyDenied || gallery.isPermanentlyDenied;
}

class PermissionService {
  final LocalStorageService _storage;

  PermissionService(this._storage);

  bool hasCompletedPermissionFlow() => _storage.hasRequestedPermissions();

  Future<void> markFlowCompleted() => _storage.setHasRequestedPermissions(true);

  Future<PermissionStatus> checkCameraStatus() => Permission.camera.status;

  Future<PermissionStatus> checkGalleryStatus() => Permission.photos.status;

  Future<PermissionResult> requestGalleryAndCamera() async {
    final statuses = await <Permission>[Permission.photos, Permission.camera].request();
    return PermissionResult(
      camera: statuses[Permission.camera] ?? PermissionStatus.denied,
      gallery: statuses[Permission.photos] ?? PermissionStatus.denied,
    );
  }

  Future<PermissionStatus> requestCameraOnly() => Permission.camera.request();

  Future<PermissionStatus> requestGalleryOnly() => Permission.photos.request();

  Future<bool> openAppSettings() async {
    return await openAppSettings();
  }

  bool isGranted(PermissionStatus status) => status.isGranted || status.isLimited;

  bool isPermanentlyDenied(PermissionStatus status) => status.isPermanentlyDenied;
}

final permissionServiceProvider = Provider<PermissionService>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return PermissionService(storage);
});
