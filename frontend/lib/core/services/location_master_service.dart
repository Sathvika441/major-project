import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_logger.dart';
import '../constants/karnataka_locations.dart';

class VillageEntry {
  final String name;
  final String code;

  const VillageEntry({required this.name, required this.code});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VillageEntry &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

class LocationMasterService {
  static const String assetPath = 'assets/Karnataka_Location_Master.json';

  bool _loaded = false;
  final List<String> _districts = [];
  final Map<String, List<String>> _taluksByDistrict = {};
  final Map<String, List<VillageEntry>> _villagesByTaluk = {};

  bool get isLoaded => _loaded;
  List<String> get districts => List.unmodifiable(_districts);

  List<String> taluksFor(String district) {
    final key = _normalizeKey(district);
    return List.unmodifiable(
      _taluksByDistrict[key] ??
          KarnatakaLocations.taluksFor(
            KarnatakaLocations.districts.contains(district) ? district : '',
          ),
    );
  }

  List<VillageEntry> villagesFor(String taluk) {
    final key = _normalizeKey(taluk);
    return List.unmodifiable(_villagesByTaluk[key] ?? const []);
  }

  String findVillageCodeByName(String taluk, String villageName) {
    final villages = villagesFor(taluk);
    final lower = villageName.trim().toLowerCase();
    for (final v in villages) {
      if (v.name.trim().toLowerCase() == lower) return v.code;
    }
    return '';
  }

  String findVillageNameByCode(String taluk, String code) {
    final villages = villagesFor(taluk);
    for (final v in villages) {
      if (v.code == code) return v.name;
    }
    return '';
  }

  static String _normalizeKey(String input) =>
      input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _toTitleCase(String input) {
    if (input.trim().isEmpty) return input;
    return input
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map(
          (word) => word.length <= 2
              ? word.toUpperCase()
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString(assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final districtsRaw = json['districts'] as List<dynamic>? ?? [];

      final seenDistrictKeys = <String>{};
      for (final d in districtsRaw) {
        final dMap = d as Map<String, dynamic>;
        final districtName = _toTitleCase(
          (dMap['district_name'] as String?) ?? '',
        );
        if (districtName.isEmpty) continue;
        final dKey = _normalizeKey(districtName);
        if (!seenDistrictKeys.contains(dKey)) {
          _districts.add(districtName);
          seenDistrictKeys.add(dKey);
          _taluksByDistrict[dKey] = [];
        }

        final taluksRaw = dMap['taluks'] as List<dynamic>? ?? [];
        final seenTalukKeys = <String>{};
        for (final t in taluksRaw) {
          final tMap = t as Map<String, dynamic>;
          final talukName = _toTitleCase((tMap['taluk_name'] as String?) ?? '');
          if (talukName.isEmpty) continue;
          final tKey = _normalizeKey(talukName);
          if (!seenTalukKeys.contains(tKey)) {
            _taluksByDistrict[dKey]!.add(talukName);
            seenTalukKeys.add(tKey);
            _villagesByTaluk[tKey] = [];
          }

          final hoblisRaw = tMap['hoblis'] as List<dynamic>? ?? [];
          final seenCodes = <String>{};
          for (final h in hoblisRaw) {
            final hMap = h as Map<String, dynamic>;
            final villagesRaw = hMap['villages'] as List<dynamic>? ?? [];
            for (final v in villagesRaw) {
              final vMap = v as Map<String, dynamic>;
              final vName = (vMap['village_name'] as String?) ?? '';
              final vCode = (vMap['village_code'] as String?) ?? '';
              if (vName.isEmpty || vCode.isEmpty || seenCodes.contains(vCode))
                continue;
              seenCodes.add(vCode);
              _villagesByTaluk[tKey]!.add(
                VillageEntry(name: vName.trim(), code: vCode),
              );
            }
          }
        }
      }
      _loaded = true;
      AppLogger.info(
        'Location master loaded: ${_districts.length} districts, '
        '${_taluksByDistrict.values.fold<int>(0, (a, b) => a + b.length)} taluks, '
        '${_villagesByTaluk.values.fold<int>(0, (a, b) => a + b.length)} villages',
        tag: 'LocationMaster',
      );
    } catch (e, stack) {
      AppLogger.error(
        'Failed to load location master, falling back to hardcoded list',
        tag: 'LocationMaster',
        error: e,
        stackTrace: stack,
      );
      _loadFallback();
      _loaded = true;
    }
  }

  void _loadFallback() {
    _districts.clear();
    _taluksByDistrict.clear();
    _villagesByTaluk.clear();
    _districts.addAll(KarnatakaLocations.districts);
    for (final d in _districts) {
      final dKey = _normalizeKey(d);
      final taluks = KarnatakaLocations.taluksFor(d);
      _taluksByDistrict[dKey] = List.of(taluks);
      for (final t in taluks) {
        final tKey = _normalizeKey(t);
        _villagesByTaluk[tKey] = [
          VillageEntry(name: '$t Village 1', code: '${tKey}_1'),
          VillageEntry(name: '$t Village 2', code: '${tKey}_2'),
        ];
      }
    }
  }
}

final locationMasterServiceProvider = Provider<LocationMasterService>(
  (ref) => LocationMasterService(),
);
