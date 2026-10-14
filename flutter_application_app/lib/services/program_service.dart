import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/program.dart';

/// Programmes des élèves : `users/{studentUid}/programs/{id}` (gérés par le coach).
class ProgramService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) => _db.collection('users/$uid/programs');

  static List<Program> _fromSnap(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => Program.fromDoc(d.id, d.data())).toList();

  /// Programmes d'un élève, du plus ancien au plus récent.
  Stream<List<Program>> watchPrograms(String studentUid) =>
      _col(studentUid).orderBy('startDate').snapshots().map(_fromSnap);

  /// Tous les programmes créés par un coach (collectionGroup `programs`).
  Stream<List<Program>> watchCoachPrograms(String coachUid) =>
      _db.collectionGroup('programs').where('coachId', isEqualTo: coachUid).snapshots().map(_fromSnap);

  Future<void> saveProgram(String studentUid, Program p) {
    if (p.id.isEmpty) {
      return _col(studentUid).add({...p.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    }
    return _col(studentUid).doc(p.id).update({
      ...p.toMap(),
      if (p.goal == null || p.goal!.trim().isEmpty) 'goal': FieldValue.delete(),
      if (p.notes == null || p.notes!.trim().isEmpty) 'notes': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProgram(String studentUid, String id) => _col(studentUid).doc(id).delete();
}
