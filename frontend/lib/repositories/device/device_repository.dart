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
    return _devices(userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => DeviceModel.fromMap({...d.data(), 'id': d.id}))
              .toList(),
        );
  }

  @override
  Future<DeviceModel> register(DeviceModel device) async {
    final reading = device.latestReading;
    if (reading != null && !reading.isValid) {
      throw ArgumentError('Sensor reading contains an abnormal value.');
    }
    await _devices(device.userId)
        .doc(device.id)
        .set(device.toMap(), SetOptions(merge: true));
    return device;
  }
}
