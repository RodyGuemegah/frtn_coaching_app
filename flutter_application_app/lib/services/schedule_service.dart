import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/schedule_slot.dart';

/// Créneaux récurrents de l'emploi du temps d'un élève.
/// Chemin Firestore : `users/{studentUid}/schedule/{id}` (élève et son coach).
class ScheduleService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) => _db.collection('users/$uid/schedule');

  /// Tous les créneaux, triés par heure de début (tri côté app : pas d'index).
  Stream<List<ScheduleSlot>> watchSlots(String uid) => _col(uid).snapshots().map((snap) {
        final list = snap.docs.map((d) => ScheduleSlot.fromDoc(d.id, d.data())).toList()
          ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
        return list;
      });

  Future<void> createSlot(String uid, ScheduleSlot slot) =>
      _col(uid).add({...slot.toMap(), 'createdAt': FieldValue.serverTimestamp()});

  Future<void> updateSlot(String uid, ScheduleSlot slot) => _col(uid).doc(slot.id).update({
        ...slot.toMap(),
        // Fin retirée → on supprime le champ (toMap ne l'écrit pas).
        if (slot.endMinutes == null) 'endMinutes': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteSlot(String uid, String id) => _col(uid).doc(id).delete();
}
