import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FarmLocalService {
  static const farmsKey = 'phase25_farms';
  static const plotsKey = 'phase25_plots';
  final SharedPreferences prefs;

  FarmLocalService(this.prefs);

  List<Map<String, dynamic>> _list(String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    return List<Map<String, dynamic>>.from(
      (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  Future<void> _save(String key, List<Map<String, dynamic>> items) =>
      prefs.setString(key, jsonEncode(items));

  Future<List<Map<String, dynamic>>> farmsForUser(String userId) async =>
      _list(farmsKey).where((e) => e['userId'] == userId && e['isActive'] != false).toList();

  Future<void> saveFarm(Map<String, dynamic> farm) async {
    final items = _list(farmsKey);
    items.removeWhere((e) => e['id'] == farm['id']);
    items.add(farm);
    await _save(farmsKey, items);
  }

  Future<List<Map<String, dynamic>>> plotsForFarm(String farmId) async =>
      _list(plotsKey).where((e) => e['farmId'] == farmId && e['isActive'] != false).toList();

  Future<void> savePlot(Map<String, dynamic> plot) async {
    final items = _list(plotsKey);
    items.removeWhere((e) => e['id'] == plot['id']);
    items.add(plot);
    await _save(plotsKey, items);
  }
}
