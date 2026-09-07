import 'package:cloud_firestore/cloud_firestore.dart';

class Exercise {
  final String name;
  final int sets, reps, restSec;
  final num load;

  Exercise({required this.name, required this.sets, required this.reps, required this.load, required this.restSec});

  factory Exercise.fromMap(Map<String, dynamic> m) => Exercise(
    name: m['name'] ?? '', sets: m['sets'] ?? 0, reps: m['reps'] ?? 0,
    load: m['load'] ?? 0, restSec: m['restSec'] ?? 0,
  );
}

class SessionModel {
  final String id, title, status;
  final DateTime date;
  final String? coachNote;
  final List<Exercise> exercises;

  SessionModel({required this.id, required this.title, required this.status,
    required this.date, this.coachNote, required this.exercises});

  factory SessionModel.fromDoc(String id, Map<String, dynamic> data) {
    return SessionModel(
      id: id,
      title: data['title'] ?? '',
      status: data['status'] ?? 'todo',
      date: (data['date'] as Timestamp).toDate(),
      coachNote: data['coachNote'],
      exercises: (data['exercises'] as List? ?? [])
          .map((e) => Exercise.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}