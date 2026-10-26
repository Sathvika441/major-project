import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/device/device_model.dart';

abstract class DeviceRepository {
  Future<List<DeviceModel>> getDevices(String userId);
  Stream<List<DeviceModel>> watchDevices(String userId);
  Future<DeviceModel> register(DeviceModel device);
}

final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => FirestoreDeviceRepository(FirebaseFirestore.instance),
);

class FirestoreDeviceRepository implements DeviceRepository {
  final FirebaseFirestore db;
  FirestoreDeviceRepository(this.db);

  CollectionReference<Map<String, dynamic>> _devices(String uid) =>
      db.collection('users').doc(uid).collection('devices');

  CollectionReference<Map<String, dynamic>> _farms(String uid) =>
      db.collection('users').doc(uid).collection('farms');

  @override
  Future<List<DeviceModel>> getDevices(String userId) async {
    final snapshot = await _devices(userId)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs
        .map((d) => DeviceModel.fromMap({...d.data(), 'id': d.id}))
        .toList();
  }

  @override
  Stream<List<DeviceModel>> watchDevices(String userId) {
    // The registration lives under a farm. userId is retained as a query
    // helper; the parent users/{uid}/farms/{farmId} path is authoritative.
    return db.collectionGroup('devices')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.data()['isActive'] != false)
            .map((doc) {
              final path = doc.reference.path.split('/');
              final farmId = path.length == 6 ? path[3] : '';
              return DeviceModel.fromMap({
                ...doc.data(),
                'id': doc.id,
                'userId': userId,
                'farmId': farmId,
              });
            })
            .where((device) => device.farmId.isNotEmpty)
            .toList());
  }

  @override
  Future<DeviceModel> register(DeviceModel device) async {
    final normalizedId = device.deviceId.trim();
    if (normalizedId.length < 1 ||
        normalizedId.length > 50 ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(normalizedId)) {
      throw ArgumentError(
        'Device ID must contain 1–50 letters, numbers, hyphens or underscores.',
      );
    }
    if (device.userId.trim().isEmpty ||
        device.farmId.trim().isEmpty ||
        device.id.trim().isEmpty) {
      throw ArgumentError('User, farm and registration IDs are required.');
    }
    final name = device.name.trim();
    if (name.length < 2 || name.length > 60) {
      throw ArgumentError('Device name must contain 2–60 characters.');
    }

    final reading = device.latestReading;
    if (reading != null && !reading.isValid) {
      throw ArgumentError('Sensor reading contains an abnormal value.');
    }

    // Validate the farm under the same UID; a client cannot attach a device
    // to another user's farm by passing an arbitrary farmId.
    final farmSnapshot = await _farms(device.userId).doc(device.farmId).get();
    final farmData = farmSnapshot.data();
    if (!farmSnapshot.exists || farmData == null ||
        farmData['isActive'] == false) {
      throw StateError('Select an active farm owned by this account.');
    }

    // Check duplicates only inside the signed-in user's device collection.
    // A client-side collectionGroup query spans every user's private devices
    // and is normally rejected by Firestore security rules. Cross-user physical
    // ID uniqueness must be enforced by a trusted backend, not a client query.
    final farmSnapshots = await _farms(device.userId).get();
    final matches = await Future.wait(farmSnapshots.docs.map((farm) =>
        _devices(device.userId, farm.id)
            .where('deviceId', isEqualTo: normalizedId)
            .get()));
    final conflicting = matches.expand((snapshot) => snapshot.docs).where((doc) => doc.id != device.id);
    if (conflicting.isNotEmpty) {
      throw StateError('This device ID is already registered to your account.');
    }

    final normalizedDevice = device.copyWith(name: name);
    await _devices(device.userId)
        .doc(device.id)
        .set(normalizedDevice.toMap(), SetOptions(merge: true));
    return normalizedDevice;
  }
}
