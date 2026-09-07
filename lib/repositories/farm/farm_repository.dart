import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/local_storage_service.dart';
import '../../models/farm/farm_model.dart';

abstract class FarmRepository {
  Future<List<FarmModel>> getFarms(String userId);
  Future<FarmModel> saveFarm(FarmModel farm);
  Future<void> deactivateFarm(String userId, String farmId);
  Future<List<PlotModel>> getPlots(String farmId);
  Future<PlotModel> savePlot(PlotModel plot);
  Future<void> deactivatePlot(String farmId, String plotId);
}

final farmRepositoryProvider = Provider<FarmRepository>((ref) =>
    LocalFarmRepository(ref.watch(localStorageServiceProvider)));

class LocalFarmRepository implements FarmRepository {
  static const _farmsKey = 'phase25_farms';
  static const _plotsKey = 'phase25_plots';
  final LocalStorageService storage;
  LocalFarmRepository(this.storage);

  List<Map<String, dynamic>> _read(String key) {
    final raw = storage.raw.getString(key);
    if (raw == null || raw.isEmpty) return [];
    return List<Map<String, dynamic>>.from(
      (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<void> _write(String key, List<Map<String, dynamic>> value) =>
      storage.raw.setString(key, jsonEncode(value));

  @override
  Future<List<FarmModel>> getFarms(String userId) async => _read(_farmsKey)
      .map(FarmModel.fromMap)
      .where((farm) => farm.userId == userId && farm.isActive)
      .toList();

  @override
  Future<FarmModel> saveFarm(FarmModel farm) async {
    final items = _read(_farmsKey);
    items.removeWhere((e) => e['id'] == farm.id);
    items.add(farm.toMap());
    await _write(_farmsKey, items);
    return farm;
  }

  @override
  Future<void> deactivateFarm(String userId, String farmId) async {
    final items = _read(_farmsKey);
    for (final item in items) {
      if (item['id'] == farmId && item['userId'] == userId) item['isActive'] = false;
    }
    await _write(_farmsKey, items);
  }

  @override
  Future<List<PlotModel>> getPlots(String farmId) async => _read(_plotsKey)
      .map(PlotModel.fromMap)
      .where((plot) => plot.farmId == farmId && plot.isActive)
      .toList();

  @override
  Future<PlotModel> savePlot(PlotModel plot) async {
    final items = _read(_plotsKey);
    items.removeWhere((e) => e['id'] == plot.id);
    items.add(plot.toMap());
    await _write(_plotsKey, items);
    return plot;
  }

  @override
  Future<void> deactivatePlot(String farmId, String plotId) async {
    final items = _read(_plotsKey);
    for (final item in items) {
      if (item['id'] == plotId && item['farmId'] == farmId) item['isActive'] = false;
    }
    await _write(_plotsKey, items);
  }
}
