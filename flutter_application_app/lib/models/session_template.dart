import 'firestore_helpers.dart';
import 'session_model.dart'; // Exercise et SessionModel

/// Séance type réutilisable par le coach : pas d'élève, pas de date.
/// Stockée dans `users/{uidCoach}/templates/{id}`.
class SessionTemplate {
  final String id;
  final String title;
  final int? durationMin;
  final String? coachNote;
  final List<Exercise> exercises;

  /// Posé par le service (heure serveur) à la création.
  final DateTime? createdAt;

  const SessionTemplate({
    required this.id,
    required this.title,
    this.durationMin,
    this.coachNote,
    required this.exercises,
    this.createdAt,
  });

  factory SessionTemplate.fromDoc(String id, Map<String, dynamic> m) => SessionTemplate(
    id: id,
    title: parseString(m['title']),
    durationMin: parseIntOrNull(m['durationMin']),
    coachNote: parseStringOrNull(m['coachNote']),
    exercises: parseMapList(m['exercises']).map(Exercise.fromMap).toList(),
    createdAt: parseDate(m['createdAt']),
  );

  /// Crée un modèle à partir d'une séance existante (« Enregistrer comme modèle »).
  factory SessionTemplate.fromSession(SessionModel s) => SessionTemplate(
    id: '',
    title: s.title,
    durationMin: s.durationMin,
    coachNote: s.coachNote,
    exercises: List.of(s.exercises),
  );

  /// Champs persistés (sans `createdAt`, posé par le service via serverTimestamp).
  Map<String, dynamic> toMap() => {
    'title': title,
    if (durationMin != null) 'durationMin': durationMin,
    if (coachNote != null && coachNote!.isNotEmpty) 'coachNote': coachNote,
    'exercises': exercises.map((e) => e.toMap()).toList(),
  };

  /// Fabrique une vraie séance à partir du modèle.
  SessionModel toSession({
    required String studentId,
    required String coachId,
    required String coachName,
    required DateTime date,
  }) {
    return SessionModel(
      id: '', // attribué par Firestore à la création
      title: title,
      status: 'todo',
      date: date,
      coachNote: coachNote,
      exercises: List.of(exercises), // copie : la séance ne partage pas la liste du modèle
      studentId: studentId,
      coachId: coachId,
      coachName: coachName,
      durationMin: durationMin,
    );
  }
}
