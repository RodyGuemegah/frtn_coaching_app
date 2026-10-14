import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/measurement.dart';

/// Mesures (pesées…) d'un élève : `users/{uid}/measurements/{id}`, partagées avec son coach.
class MeasurementService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) => _db.collection('users/$uid/measurements');

  /// Toutes les mesures, de la plus ancienne à la plus récente, en direct.
  Stream<List<Measurement>> watchMeasurements(String uid) => _col(uid)
      .orderBy('date')
      .snapshots()
      .map((snap) => snap.docs.map((d) => Measurement.fromDoc(d.id, d.data())).toList());

  /// Ajoute ou modifie une mesure. Si [syncProfileWeight] est vrai (mesure la
  /// plus récente), le poids du profil `users/{uid}.weightKg` est ensuite mis à jour.
  /// Cette synchro est « au mieux » : si elle échoue (ancien compte sans profil),
  /// la mesure reste enregistrée.
  Future<void> saveMeasurement(String uid, Measurement m, {required bool syncProfileWeight}) async {
    if (m.id.isEmpty) {
      await _col(uid).add({...m.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await _col(uid).doc(m.id).update({
        ...m.toMap(),
        // Champs optionnels vidés → supprimés.
        if (m.waistCm == null) 'waistCm': FieldValue.delete(),
        if (m.bodyFatPct == null) 'bodyFatPct': FieldValue.delete(),
        if (m.note == null || m.note!.trim().isEmpty) 'note': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    if (syncProfileWeight) {
      try {
        await _db.doc('users/$uid').update({'weightKg': m.weightKg});
      } catch (_) {}
    }
  }

  Future<void> deleteMeasurement(String uid, String id) => _col(uid).doc(id).delete();
}
