import 'package:flutter_application_app/models/measurement.dart';
import 'package:flutter_application_app/models/program.dart';
import 'package:flutter_application_app/models/session_model.dart';
import 'package:flutter_application_app/utils/program_report.dart';
import 'package:flutter_application_app/utils/program_stats.dart';
import 'package:flutter_test/flutter_test.dart';

// Programme de 4 semaines : du lundi 7/09 au dimanche 4/10 2026 (fin exclusive le 5/10).
final _program = Program(id: 'p', title: 'Remise en forme', startDate: DateTime(2026, 9, 7), weeks: 4);

SessionModel _s(String id, DateTime d, {bool done = false, Ressenti? feeling}) => SessionModel(
  id: id,
  title: id,
  status: done ? 'done' : 'todo',
  date: d,
  exercises: const [],
  feedback: feeling == null ? null : SessionFeedback(ressenti: feeling, createdAt: d),
);

Measurement _m(String id, DateTime d, num kg, {num? waist, num? fat}) =>
    Measurement(id: id, date: d, weightKg: kg, waistCm: waist, bodyFatPct: fat);

void main() {
  final sessions = [
    _s('avant', DateTime(2026, 9, 1, 18), done: true, feeling: Ressenti.facile), // hors programme
    _s('s1', DateTime(2026, 9, 8, 18), done: true, feeling: Ressenti.correct), // semaine 1
    _s('s2', DateTime(2026, 9, 10, 18), done: true, feeling: Ressenti.difficile), // semaine 1
    _s('s3', DateTime(2026, 9, 15, 18)), // semaine 2 — manquée
    _s('s4', DateTime(2026, 9, 22, 18), done: true, feeling: Ressenti.difficile), // semaine 3
    _s('s5', DateTime(2026, 9, 29, 18), done: true), // semaine 4, sans ressenti
    _s('apres', DateTime(2026, 10, 6, 18)), // hors programme
  ];
  final measures = [
    _m('m0', DateTime(2026, 9, 1), 72.4, waist: 84), // avant : référence de départ
    _m('m1', DateTime(2026, 9, 20), 71.6),
    _m('m2', DateTime(2026, 10, 3), 70.9, waist: 81.5),
    _m('m3', DateTime(2026, 10, 10), 70.5), // après le programme
  ];

  test('programme terminé : assiduité, semaines, ressentis, mesures', () {
    final r = programReport(program: _program, sessions: sessions, measurements: measures, now: DateTime(2026, 10, 14));

    expect(r.status, ProgramStatus.finished);
    expect(r.planned, 5);
    expect(r.done, 4);
    expect(r.missed, 1);
    expect(r.upcoming, 0);
    expect(r.attendancePct, 80);

    expect(r.weeks.map((w) => '${w.done}/${w.planned}'), ['2/2', '0/1', '1/1', '1/1']);
    expect(r.weeks[1].missed, 1);

    expect(r.feelings[Ressenti.difficile], 2);
    expect(r.feelings[Ressenti.correct], 1);
    expect(r.feelingsCount, 3);
    expect(r.dominantFeeling, Ressenti.difficile);

    expect(r.weight!.start, 72.4);
    expect(r.weight!.end, 70.9);
    expect(r.weight!.delta, closeTo(-1.5, 1e-9));
    expect(r.waist!.delta, closeTo(-2.5, 1e-9));
    expect(r.bodyFat, isNull, reason: 'aucune masse grasse saisie');
    expect(r.measurements.map((m) => m.id), ['m0', 'm1', 'm2']);
  });

  test('programme en cours : les séances futures ne comptent pas comme manquées', () {
    // Situation au 20/09 : les séances des 22 et 29/09 ne sont pas encore faites.
    final asOf20 = [
      for (final s in sessions)
        s.date.isAfter(DateTime(2026, 9, 20)) ? _s(s.id, s.date) : s,
    ];
    final r = programReport(program: _program, sessions: asOf20, measurements: measures, now: DateTime(2026, 9, 20));
    expect(r.status, ProgramStatus.active);
    expect(r.done, 2);
    expect(r.missed, 1); // s3 (15/09)
    expect(r.upcoming, 2); // s4, s5
    expect(r.attendancePct, 67);
    expect(r.weeks[3].started(DateTime(2026, 9, 20)), isFalse);
  });

  test('sans séance ni mesure : pas de pourcentage ni d\'écart', () {
    final r = programReport(program: _program, sessions: const [], measurements: const [], now: DateTime(2026, 10, 14));
    expect(r.planned, 0);
    expect(r.attendancePct, isNull);
    expect(r.dominantFeeling, isNull);
    expect(r.weight, isNull);
    expect(r.weeks.length, 4);
  });

  test('une seule mesure dans la période : pas d\'écart', () {
    final r = programReport(
      program: _program,
      sessions: const [],
      measurements: [_m('x', DateTime(2026, 9, 15), 70)],
      now: DateTime(2026, 10, 14),
    );
    expect(r.weight, isNull);
  });
}
