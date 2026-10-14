import '../models/app_user.dart';
import '../models/program.dart';
import '../models/session_model.dart';
import 'format.dart';
import 'program_stats.dart';
import 'session_stats.dart';

/// Calculs purs (testables sans Firebase) pour l'espace coach.

class StudentStats {
  /// Séances dont la date est passée.
  final int pastTotal;

  /// Séances marquées faites (toutes dates).
  final int done;

  /// faites / passées en %, `null` sans séance passée.
  final int? attendancePct;

  /// Dernière séance ayant un ressenti (la plus récente).
  final SessionModel? lastFeedbackSession;

  /// Nombre de retours faits par l'élève et non encore validés par le coach.
  final int pendingFeedback;

  final SessionModel? next;

  /// Programme courant (en cours, sinon à venir, sinon le dernier terminé).
  final Program? program;

  /// Le programme est-il à renouveler (fin ≤ 7 j ou terminé sans suite) ?
  final bool programNeedsRenewal;

  const StudentStats({
    required this.pastTotal,
    required this.done,
    required this.attendancePct,
    required this.lastFeedbackSession,
    required this.pendingFeedback,
    required this.next,
    this.program,
    this.programNeedsRenewal = false,
  });

  bool get hasPendingFeedback => pendingFeedback > 0;

  /// Assiduité faible : < 70 % avec au moins 3 séances passées.
  bool get lowAttendance => attendancePct != null && attendancePct! < 70 && pastTotal >= 3;

  static const empty = StudentStats(
    pastTotal: 0,
    done: 0,
    attendancePct: null,
    lastFeedbackSession: null,
    pendingFeedback: 0,
    next: null,
  );
}

StudentStats studentStats(List<SessionModel> sessions, DateTime now, {List<Program> programs = const []}) {
  final past = sessions.where((s) => s.date.isBefore(now)).toList();
  final donePast = past.where((s) => s.isDone).length;

  SessionModel? lastFeedback;
  for (final s in sessions) {
    if (s.feedback == null) continue;
    if (lastFeedback == null || s.feedback!.createdAt.isAfter(lastFeedback.feedback!.createdAt)) {
      lastFeedback = s;
    }
  }

  return StudentStats(
    pastTotal: past.length,
    done: sessions.where((s) => s.isDone).length,
    attendancePct: past.isEmpty ? null : (donePast * 100 / past.length).round(),
    lastFeedbackSession: lastFeedback,
    pendingFeedback: sessions.where((s) => s.hasPendingFeedback).length,
    next: nextSession(sessions, now),
    program: currentProgram(programs, now),
    programNeedsRenewal: needsRenewal(programs, now),
  );
}

enum AlertReason { pendingFeedback, programRenewal, lowAttendance }

class StudentAlert {
  final AppUser student;
  final AlertReason reason;
  final StudentStats stats;
  const StudentAlert({required this.student, required this.reason, required this.stats});
}

class CoachStats {
  final int students;
  final int sessionsToday;
  final int pendingFeedback;
  final int? attendanceAvgPct;

  /// Nombre d'élèves dont le programme est à renouveler.
  final int programsToRenew;
  final List<StudentAlert> alerts;
  final Map<String, StudentStats> byStudent;

  const CoachStats({
    required this.students,
    required this.sessionsToday,
    required this.pendingFeedback,
    required this.attendanceAvgPct,
    this.programsToRenew = 0,
    required this.alerts,
    required this.byStudent,
  });

  StudentStats of(String uid) => byStudent[uid] ?? StudentStats.empty;
}

/// [allSessions] = séances assignées par le coach (tous élèves confondus) ;
/// [programs] = programmes créés par le coach (tous élèves confondus).
CoachStats coachStats(
  List<AppUser> students,
  List<SessionModel> allSessions,
  DateTime now, {
  List<Program> programs = const [],
}) {
  final grouped = <String, List<SessionModel>>{};
  for (final s in allSessions) {
    grouped.putIfAbsent(s.studentId, () => []).add(s);
  }
  final programsByStudent = <String, List<Program>>{};
  for (final p in programs) {
    programsByStudent.putIfAbsent(p.studentId, () => []).add(p);
  }

  final byStudent = <String, StudentStats>{
    for (final st in students)
      st.uid: studentStats(grouped[st.uid] ?? const [], now, programs: programsByStudent[st.uid] ?? const []),
  };

  final past = allSessions.where((s) => s.date.isBefore(now)).toList();
  final attendanceAvg = past.isEmpty ? null : (past.where((s) => s.isDone).length * 100 / past.length).round();

  final alerts = <StudentAlert>[];
  for (final st in students) {
    final stats = byStudent[st.uid]!;
    // Une seule alerte par élève, par ordre de priorité.
    if (stats.hasPendingFeedback) {
      alerts.add(StudentAlert(student: st, reason: AlertReason.pendingFeedback, stats: stats));
    } else if (stats.programNeedsRenewal) {
      alerts.add(StudentAlert(student: st, reason: AlertReason.programRenewal, stats: stats));
    } else if (stats.lowAttendance) {
      alerts.add(StudentAlert(student: st, reason: AlertReason.lowAttendance, stats: stats));
    }
  }

  return CoachStats(
    students: students.length,
    sessionsToday: allSessions.where((s) => isSameDay(s.date, now)).length,
    pendingFeedback: allSessions.where((s) => s.hasPendingFeedback).length,
    attendanceAvgPct: attendanceAvg,
    programsToRenew: byStudent.values.where((s) => s.programNeedsRenewal).length,
    alerts: alerts,
    byStudent: byStudent,
  );
}
