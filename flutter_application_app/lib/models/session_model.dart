import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_helpers.dart';

class Exercise {
  final String name;
  final int sets, reps, restSec;
  final num load;

  const Exercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.load,
    required this.restSec,
  });

  factory Exercise.fromMap(Map<String, dynamic> m) => Exercise(
    name: parseString(m['name']),
    sets: parseInt(m['sets']),
    reps: parseInt(m['reps']),
    load: parseNum(m['load']),
    restSec: parseInt(m['restSec']),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'sets': sets,
    'reps': reps,
    'load': load,
    'restSec': restSec,
  };

  /// "4 × 6 reps · 60 kg · repos 2 min" — "PDC" (poids du corps) si aucune charge.
  String get label {
    final parts = <String>['$sets × $reps reps', load > 0 ? '${_formatLoad(load)} kg' : 'PDC'];
    if (restSec > 0) {
      parts.add(restSec % 60 == 0 ? 'repos ${restSec ~/ 60} min' : 'repos ${restSec}s');
    }
    return parts.join(' · ');
  }

  static String _formatLoad(num load) => load % 1 == 0 ? load.toInt().toString() : load.toString();
}

enum Ressenti {
  facile('facile', 'Facile', '😀'),
  correct('correct', 'Correct', '🙂'),
  difficile('difficile', 'Difficile', '😅');

  final String key;
  final String label;
  final String emoji;
  const Ressenti(this.key, this.label, this.emoji);

  static Ressenti? fromKey(String? key) {
    for (final r in values) {
      if (r.key == key) return r;
    }
    return null;
  }
}

/// Retour de l'élève après une séance.
class SessionFeedback {
  final Ressenti ressenti;
  final String? comment;
  final DateTime createdAt;

  const SessionFeedback({required this.ressenti, this.comment, required this.createdAt});

  static SessionFeedback? fromMap(Map<String, dynamic> m) {
    final r = Ressenti.fromKey(parseStringOrNull(m['ressenti']));
    if (r == null) return null;
    return SessionFeedback(
      ressenti: r,
      comment: parseStringOrNull(m['comment']),
      createdAt: parseDate(m['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'ressenti': ressenti.key,
    if (comment != null) 'comment': comment,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

class SessionModel {
  final String id, title, status;
  final DateTime date;
  final String? coachNote;
  final List<Exercise> exercises;
  final String studentId, coachId;
  final String? coachName;
  final int? durationMin;
  final DateTime? doneAt;
  final SessionFeedback? feedback;
  final bool feedbackValidated;

  const SessionModel({
    required this.id,
    required this.title,
    required this.status,
    required this.date,
    this.coachNote,
    required this.exercises,
    this.studentId = '',
    this.coachId = '',
    this.coachName,
    this.durationMin,
    this.doneAt,
    this.feedback,
    this.feedbackValidated = false,
  });

  bool get isDone => status == 'done';

  /// Séance faite avec un ressenti que le coach n'a pas encore validé.
  bool get hasPendingFeedback => isDone && feedback != null && !feedbackValidated;

  factory SessionModel.fromDoc(String id, Map<String, dynamic> data) {
    final rawFeedback = data['feedback'];
    return SessionModel(
      id: id,
      title: parseString(data['title']),
      status: parseString(data['status'], 'todo'),
      date: parseDate(data['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      coachNote: parseStringOrNull(data['coachNote']),
      exercises: parseMapList(data['exercises']).map(Exercise.fromMap).toList(),
      studentId: parseString(data['studentId']),
      coachId: parseString(data['coachId']),
      coachName: parseStringOrNull(data['coachName']),
      durationMin: parseIntOrNull(data['durationMin']),
      doneAt: parseDate(data['doneAt']),
      feedback: rawFeedback == null ? null : SessionFeedback.fromMap(parseMap(rawFeedback)),
      feedbackValidated: data['feedbackValidated'] == true,
    );
  }

  /// Champs persistés à la création (sans `createdAt`, posé par le service).
  Map<String, dynamic> toMap() => {
    'title': title,
    'status': status,
    'date': Timestamp.fromDate(date),
    if (coachNote != null && coachNote!.isNotEmpty) 'coachNote': coachNote,
    'exercises': exercises.map((e) => e.toMap()).toList(),
    'studentId': studentId,
    'coachId': coachId,
    if (coachName != null) 'coachName': coachName,
    if (durationMin != null) 'durationMin': durationMin,
    'feedbackValidated': feedbackValidated,
  };
}
