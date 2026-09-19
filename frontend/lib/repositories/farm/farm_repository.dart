import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/farm/farm_model.dart';

abstract class FarmRepository {
  Future<List<FarmModel>> getFarms(String userId);
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
  Future<FarmModel> saveFarm(FarmModel farm) async {
    await _farms(farm.userId).doc(farm.id).set({
      ...farm.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return farm;
  }

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