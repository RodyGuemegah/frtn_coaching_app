import 'package:flutter_application_app/models/app_user.dart';
import 'package:flutter_application_app/models/session_model.dart';
import 'package:flutter_application_app/utils/coach_stats.dart';
import 'package:flutter_test/flutter_test.dart';

const _lucas = AppUser(uid: 'lucas', email: 'lucas@test.fr', displayName: 'Lucas Martin', firstName: 'Lucas', lastName: 'Martin');
const _emma = AppUser(uid: 'emma', email: 'emma@test.fr', displayName: 'Emma Bertrand', firstName: 'Emma', lastName: 'Bertrand');

SessionModel _s(String student, DateTime date, {bool done = false, SessionFeedback? feedback, bool validated = false}) =>
    SessionModel(
      id: '$student-${date.millisecondsSinceEpoch}',
      title: 'Séance',
      status: done ? 'done' : 'todo',
      date: date,
      exercises: const [],
      studentId: student,
      coachId: 'coach',
      feedback: feedback,
      feedbackValidated: validated,
    );

void main() {
  final now = DateTime(2026, 9, 16, 10);
  final fb = SessionFeedback(ressenti: Ressenti.difficile, comment: 'Dur', createdAt: DateTime(2026, 9, 15, 19));

  test('retours à valider et alerte pendingFeedback', () {
    final sessions = [
      _s('lucas', DateTime(2026, 9, 15, 18), done: true, feedback: fb),
      _s('emma', DateTime(2026, 9, 14, 18), done: true, feedback: fb, validated: true),
    ];
    final stats = coachStats([_lucas, _emma], sessions, now);
    expect(stats.pendingFeedback, 1);
    expect(stats.alerts.length, 1);
    expect(stats.alerts.first.student.uid, 'lucas');
    expect(stats.alerts.first.reason, AlertReason.pendingFeedback);
    expect(stats.of('lucas').lastFeedbackSession, isNotNull);
    expect(stats.of('emma').hasPendingFeedback, isFalse);
  });

  test("séances aujourd'hui et assiduité moyenne", () {
    final sessions = [
      _s('lucas', DateTime(2026, 9, 16, 18)),
      _s('lucas', DateTime(2026, 9, 16, 7), done: true),
      _s('emma', DateTime(2026, 9, 10), done: true),
      _s('emma', DateTime(2026, 9, 12)),
    ];
    final stats = coachStats([_lucas, _emma], sessions, now);
    expect(stats.sessionsToday, 2);
    // passées : lucas 07h (faite), emma 10 (faite), emma 12 (non faite) → 2/3
    expect(stats.attendanceAvgPct, 67);
  });

  test('alerte lowAttendance à partir de 3 séances passées sous 70 %', () {
    final sessions = [
      _s('emma', DateTime(2026, 9, 1)),
      _s('emma', DateTime(2026, 9, 3)),
      _s('emma', DateTime(2026, 9, 5), done: true),
    ];
    final stats = coachStats([_lucas, _emma], sessions, now);
    expect(stats.of('emma').attendancePct, 33);
    expect(stats.alerts.single.reason, AlertReason.lowAttendance);
    expect(stats.of('lucas').attendancePct, isNull);
    expect(stats.attendanceAvgPct, 33);
  });

  test('sans séance : stats vides, pas d\'alerte', () {
    final stats = coachStats([_lucas], const [], now);
    expect(stats.students, 1);
    expect(stats.sessionsToday, 0);
    expect(stats.attendanceAvgPct, isNull);
    expect(stats.alerts, isEmpty);
    expect(stats.of('inconnu').pastTotal, 0);
  });
}
