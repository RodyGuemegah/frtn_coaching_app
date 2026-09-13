import '../models/session_model.dart';

/// Calculs purs (testables sans Firebase) sur une liste de séances.

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Lundi 00:00 de la semaine de [d].
DateTime startOfWeek(DateTime d) => startOfDay(d).subtract(Duration(days: d.weekday - 1));

/// Prochaine séance non faite, à partir d'aujourd'hui (les séances manquées du passé sont ignorées).
SessionModel? nextSession(List<SessionModel> sessions, DateTime now) {
  final today = startOfDay(now);
  final upcoming = sessions.where((s) => !s.isDone && !s.date.isBefore(today)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return upcoming.isEmpty ? null : upcoming.first;
}

/// Séances de la semaine courante (lundi 00:00 inclus → lundi suivant exclu).
({int done, int total}) weekCount(List<SessionModel> sessions, DateTime now) {
  final start = startOfWeek(now);
  final end = start.add(const Duration(days: 7));
  final week = sessions.where((s) => !s.date.isBefore(start) && s.date.isBefore(end)).toList();
  return (done: week.where((s) => s.isDone).length, total: week.length);
}

/// Assiduité du mois courant sur les séances déjà passées : faites / passées, en %.
/// `null` s'il n'y a aucune séance passée ce mois-ci.
int? monthAttendancePct(List<SessionModel> sessions, DateTime now) {
  final monthStart = DateTime(now.year, now.month);
  final past = sessions.where((s) => !s.date.isBefore(monthStart) && s.date.isBefore(now)).toList();
  if (past.isEmpty) return null;
  return (past.where((s) => s.isDone).length * 100 / past.length).round();
}

int totalDone(List<SessionModel> sessions) => sessions.where((s) => s.isDone).length;
