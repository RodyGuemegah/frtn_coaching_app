import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';

class SessionService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) => _db.collection('users/$uid/sessions');

  static List<SessionModel> _fromSnap(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => SessionModel.fromDoc(d.id, d.data())).toList();

  /// Toutes les séances d'un utilisateur, triées par date.
  Stream<List<SessionModel>> watchSessions(String uid) =>
      _col(uid).orderBy('date').snapshots().map(_fromSnap);

  /// Une séance précise (null si supprimée).
  Stream<SessionModel?> watchSession(String uid, String id) => _col(uid)
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? SessionModel.fromDoc(d.id, d.data()!) : null);

  /// Toutes les séances assignées par un coach à ses élèves depuis [since]
  /// (requête collectionGroup — nécessite l'index composite coachId + date).
  Stream<List<SessionModel>> watchCoachSessions(String coachUid, {required DateTime since}) => _db
      .collectionGroup('sessions')
      .where('coachId', isEqualTo: coachUid)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
      .orderBy('date')
      .snapshots()
      .map(_fromSnap);

  /// Crée une séance dans `users/{studentUid}/sessions` et retourne son id.
  Future<String> createSession({required String studentUid, required SessionModel session}) async {
    final ref = await _col(studentUid).add({
      ...session.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Marque la séance comme faite avec le ressenti de l'élève.
  /// N'écrit que `status`, `doneAt` et `feedback` (seuls champs autorisés à l'élève par les règles).
  Future<void> markDone(String uid, String id, SessionFeedback feedback) => _col(uid).doc(id).update({
    'status': 'done',
    'doneAt': FieldValue.serverTimestamp(),
    'feedback': feedback.toMap(),
  });

  /// Le coach valide le retour de l'élève.
  Future<void> validateFeedback(String studentUid, String id) => _col(studentUid).doc(id).update({
    'feedbackValidated': true,
    'validatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> deleteSession(String uid, String id) => _col(uid).doc(id).delete();
}
