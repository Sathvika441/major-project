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

  CollectionReference<Map<String, dynamic>> _farms(String uid) =>
      db.collection('users').doc(uid).collection('farms');

  CollectionReference<Map<String, dynamic>> _devices(
    String uid,
    String farmId,
  ) => _farms(uid).doc(farmId).collection('devices');

  @override
  Future<List<DeviceModel>> getDevices(String userId) async {
    final farms = await _farms(userId).get();
    final snapshots = await Future.wait(
      farms.docs.map((farm) => _devices(userId, farm.id)
          .where('isActive', isEqualTo: true)
          .get()),
    );
    final devices = <DeviceModel>[];
    for (var i = 0; i < farms.docs.length; i++) {
      final farmId = farms.docs[i].id;
      for (final doc in snapshots[i].docs) {
        devices.add(DeviceModel.fromMap({
          ...doc.data(),
          'id': doc.id,
          'userId': userId,
          'farmId': farmId,
        }));
      }
    }
    return devices;
  }

  @override
  Stream<List<DeviceModel>> watchDevices(String userId) {
    // Parent path is the authoritative relationship. userId remains a query
    // helper on each registration so collection-group watches are scoped.
    return db.collectionGroup('devices')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.data()['isActive'] != false)
            .map((doc) {
              final path = doc.reference.path.split('/');
              final farmId = path.length == 6 &&
                      path[0] == 'users' &&
                      path[1] == userId &&
                      path[2] == 'farms' &&
                      path[4] == 'devices'
                  ? path[3]
                  : '';
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
    if (normalizedId.isEmpty ||
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

    final farmSnapshot = await _farms(device.userId).doc(device.farmId).get();
    final farmData = farmSnapshot.data();
    if (!farmSnapshot.exists ||
        farmData == null ||
        farmData['isActive'] == false) {
      throw StateError('Select an active farm owned by this account.');
    }

    // Enforce physical ID uniqueness across this user's farms without querying
    // another user's private device records from the Flutter client.
    final farms = await _farms(device.userId).get();
    final matches = await Future.wait(farms.docs.map((farm) =>
        _devices(device.userId, farm.id)
            .where('deviceId', isEqualTo: normalizedId)
            .get()));
    final conflicting = matches.expand((snapshot) => snapshot.docs).where(
          (doc) => doc.id != device.id,
        );
    if (conflicting.isNotEmpty) {
      throw StateError('This device ID is already registered to your account.');
    }

    final normalizedDevice = device.copyWith(name: name);
    await _devices(device.userId, device.farmId)
        .doc(device.id)
        .set(normalizedDevice.toMap(), SetOptions(merge: true));
    return normalizedDevice;
  }
}
