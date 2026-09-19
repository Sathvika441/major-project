import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/farm/farm_model.dart';
import '../../core/services/crop_growth_stage_service.dart';

abstract class FarmRepository {
  Future<List<FarmModel>> getFarms(String userId);
  Stream<List<FarmModel>> watchFarms(String userId);
  Future<FarmModel> saveFarm(FarmModel farm);
  Future<void> deactivateFarm(String userId, String farmId);
  Future<List<PlotModel>> getPlots(String userId, String farmId);
  Future<PlotModel> savePlot(String userId, PlotModel plot);
  Future<void> deactivatePlot(String userId, String farmId, String plotId);
}

final farmRepositoryProvider = Provider<FarmRepository>((ref) => FirestoreFarmRepository(FirebaseFirestore.instance));

class FirestoreFarmRepository implements FarmRepository {
  final FirebaseFirestore db;
  FirestoreFarmRepository(this.db);

  CollectionReference<Map<String, dynamic>> _farms(String uid) =>
      db.collection('users').doc(uid).collection('farms');

  CollectionReference<Map<String, dynamic>> _plots(String uid, String farmId) =>
      _farms(uid).doc(farmId).collection('plots');

  @override
  Future<List<FarmModel>> getFarms(String userId) async {
    final snapshot = await _farms(userId).where('isActive', isEqualTo: true).get();
    return snapshot.docs
        .map((d) => FarmModel.fromMap({...d.data(), 'id': d.id}))
        .toList();
  }

  @override
  Stream<List<FarmModel>> watchFarms(String userId) {
    return _farms(userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((d) => FarmModel.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  @override
  Future<FarmModel> saveFarm(FarmModel farm) async {
    const growthStageService = CropGrowthStageService();
    if (farm.plantingDate != null) {
      growthStageService.validatePlantingDate(farm.plantingDate!);
    }

    final farmRef = _farms(farm.userId).doc(farm.id);
    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(farmRef);
      final data = <String, dynamic>{
        ...farm.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final previousDate = _readDateTime(snapshot.data()?['plantingDate']);
      final newDate = farm.plantingDate;

      if (snapshot.exists &&
          previousDate != null &&
          newDate != null &&
          !_sameCalendarDate(previousDate, newDate)) {
        final history = <Map<String, dynamic>>[
          ...((snapshot.data()?['plantingDateHistory'] as List?)
                  ?.whereType<Map>()
                  .map((entry) => Map<String, dynamic>.from(entry)) ??
              const <Map<String, dynamic>>[]),
          {
            'previousDate': previousDate.toIso8601String(),
            'newDate': newDate.toIso8601String(),
            'recordedAt': DateTime.now().toUtc().toIso8601String(),
            'source': 'farm_details_edit',
          },
        ];
        data['plantingDateHistory'] = history;
      }

      transaction.set(farmRef, data, SetOptions(merge: true));
    });

    return farm;
  }

  DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _sameCalendarDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Future<void> deactivateFarm(String userId, String farmId) =>
      _farms(userId).doc(farmId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<List<PlotModel>> getPlots(String userId, String farmId) async {
    final snapshot = await _plots(userId, farmId)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs
        .map((d) => PlotModel.fromMap({...d.data(), 'id': d.id}))
        .toList();
  }

  @override
  Future<PlotModel> savePlot(String userId, PlotModel plot) async {
    await _plots(userId, plot.farmId).doc(plot.id).set(plot.toMap(), SetOptions(merge: true));
    return plot;
  }

  @override
  Future<void> deactivatePlot(String userId, String farmId, String plotId) =>
      _plots(userId, farmId).doc(plotId).update({'isActive': false});
}