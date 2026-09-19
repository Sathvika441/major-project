import 'package:cloud_firestore/cloud_firestore.dart';

import 'irrigation_models.dart';

abstract class IrrigationAuditLog {
  Future<void> record(IrrigationAuditRecord record);
}

class InMemoryIrrigationAuditLog implements IrrigationAuditLog {
  final List<IrrigationAuditRecord> records = [];
  @override
  Future<void> record(IrrigationAuditRecord record) async => records.add(record);
}

class FirestoreIrrigationAuditLog implements IrrigationAuditLog {
  final FirebaseFirestore db;
  final String userId;
  FirestoreIrrigationAuditLog({required this.db, required this.userId});

  CollectionReference<Map<String, dynamic>> get _events =>
      db.collection('users').doc(userId).collection('irrigationAudit');

  @override
  Future<void> record(IrrigationAuditRecord record) async {
    await _events.doc(record.id).set({
      ...record.toMap(),
      'serverRecordedAt': FieldValue.serverTimestamp(),
    });
  }
}