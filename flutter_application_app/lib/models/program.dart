import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_helpers.dart';

/// Programme d'accompagnement d'un élève (ex : « Prise de masse — Phase 2 », 12 semaines).
/// Stocké dans `users/{studentUid}/programs/{id}` ; créé et géré par le coach.
class Program {
  final String id;
  final String title;
  final String? goal;
  final DateTime startDate;

  /// Durée en semaines (1 à 52).
  final int weeks;
  final String? notes;
  final String studentId;
  final String coachId;

  const Program({
    required this.id,
    required this.title,
    this.goal,
    required this.startDate,
    required this.weeks,
    this.notes,
    this.studentId = '',
    this.coachId = '',
  });

  /// Premier jour APRÈS le programme (fin exclusive).
  DateTime get endDate => DateTime(startDate.year, startDate.month, startDate.day + weeks * 7);

  /// Dernier jour du programme (inclus), pour l'affichage.
  DateTime get lastDay => DateTime(endDate.year, endDate.month, endDate.day - 1);

  factory Program.fromDoc(String id, Map<String, dynamic> m) => Program(
    id: id,
    title: parseString(m['title']),
    goal: parseStringOrNull(m['goal']),
    startDate: parseDate(m['startDate']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    weeks: parseInt(m['weeks'], 1).clamp(1, 52),
    notes: parseStringOrNull(m['notes']),
    studentId: parseString(m['studentId']),
    coachId: parseString(m['coachId']),
  );

  /// Champs persistés (sans `createdAt`, posé par le service).
  Map<String, dynamic> toMap() => {
    'title': title,
    if (goal != null && goal!.trim().isNotEmpty) 'goal': goal!.trim(),
    'startDate': Timestamp.fromDate(DateTime(startDate.year, startDate.month, startDate.day)),
    'weeks': weeks,
    if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
    'studentId': studentId,
    'coachId': coachId,
  };
}
