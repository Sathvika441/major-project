import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/local_storage_service.dart';
import '../../models/device/device_model.dart';

abstract class DeviceRepository {
  Future<List<DeviceModel>> getDevices(String userId);
  Future<DeviceModel> register(DeviceModel device);
}

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) =>
    LocalDeviceRepository(ref.watch(localStorageServiceProvider)));

class LocalDeviceRepository implements DeviceRepository {
  static const _key = 'phase25_devices';
  final LocalStorageService storage;
  LocalDeviceRepository(this.storage);

  List<Map<String, dynamic>> _read() {
    final raw = storage.raw.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    return List<Map<String, dynamic>>.from(
      (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<void> _write(List<Map<String, dynamic>> values) =>
      storage.raw.setString(_key, jsonEncode(values));

  @override
  Future<List<DeviceModel>> getDevices(String userId) async => _read()
      .map(DeviceModel.fromMap)
      .where((device) => device.userId == userId && device.isActive)
      .toList();

  @override
  Future<DeviceModel> register(DeviceModel device) async {
    final reading = device.latestReading;
    if (reading != null && !reading.isValid) {
      throw ArgumentError('Sensor reading contains an abnormal value.');
    }
    final values = _read();
    values.removeWhere((e) => e['id'] == device.id);
    values.add(device.toMap());
    await _write(values);
    return device;
  }
}
