import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_template.dart';

/// Lecture / écriture des modèles de séances d'un coach.
/// Chemin Firestore : `users/{coachUid}/templates/{id}`.
class TemplateService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String coachUid) =>
      _db.collection('users/$coachUid/templates');

  /// Tous les modèles du coach, triés par titre (A → Z), mis à jour en direct.
  /// Tri côté app : pas d'index Firestore à créer.
  Stream<List<SessionTemplate>> watchTemplates(String coachUid) => _col(coachUid).snapshots().map((snap) {
        final list = snap.docs.map((d) => SessionTemplate.fromDoc(d.id, d.data())).toList()
          ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        return list;
      });

  /// Enregistre un nouveau modèle et retourne son id.
  Future<String> createTemplate(String coachUid, SessionTemplate template) async {
    final ref = await _col(coachUid).add({
      ...template.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Met à jour le contenu d'un modèle existant (titre, durée, consigne, exercices).
  /// `createdAt` n'est pas touché ; les champs optionnels vidés sont supprimés.
  Future<void> updateTemplate(String coachUid, SessionTemplate template) {
    final note = template.coachNote?.trim();
    return _col(coachUid).doc(template.id).update({
      'title': template.title,
      'exercises': template.exercises.map((e) => e.toMap()).toList(),
      'durationMin': template.durationMin ?? FieldValue.delete(),
      'coachNote': (note == null || note.isEmpty) ? FieldValue.delete() : note,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Supprime un modèle. Les séances déjà créées à partir de ce modèle ne sont pas touchées.
  Future<void> deleteTemplate(String coachUid, String id) => _col(coachUid).doc(id).delete();
}
