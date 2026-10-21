import '../models/measurement.dart';
import '../models/program.dart';
import '../models/session_model.dart';
import 'format.dart';
import 'program_stats.dart';
import 'progress_stats.dart';
import 'session_stats.dart';

/// Bilan d'une semaine du programme.
class WeekReport {
  /// Numéro de la semaine (1 = première semaine du programme).
  final int week;
  final DateTime start;
  final int planned;
  final int done;

  /// Séances passées et non faites.
  final int missed;

  const WeekReport({required this.week, required this.start, required this.planned, required this.done, required this.missed});

  /// La semaine est-elle déjà commencée ?
  bool started(DateTime now) => !start.isAfter(now);
}

/// Écart d'une mesure entre le début et la fin du programme.
class MeasureDelta {
  final num start;
  final num end;
  const MeasureDelta(this.start, this.end);
  num get delta => end - start;
}

/// Bilan complet d'un programme (pur, testable sans Firebase).
class ProgramReport {
  final Program program;
  final ProgramStatus status;

  /// Fin de la période analysée : fin du programme, ou aujourd'hui s'il est en cours.
  final DateTime periodEnd;

  final int planned;
  final int done;
  final int missed;
  final int upcoming;

  /// faites / (faites + manquées), en % ; `null` si aucune séance n'est encore échue.
  final int? attendancePct;

  final List<WeekReport> weeks;

  /// Nombre de ressentis par type (facile / correct / difficile).
  final Map<Ressenti, int> feelings;

  final MeasureDelta? weight;
  final MeasureDelta? waist;
  final MeasureDelta? bodyFat;

  /// Mesures de la période (triées), pour la courbe.
  final List<Measurement> measurements;

  const ProgramReport({
    required this.program,
    required this.status,
    required this.periodEnd,
    required this.planned,
    required this.done,
    required this.missed,
    required this.upcoming,
    required this.attendancePct,
    required this.weeks,
    required this.feelings,
    required this.weight,
    required this.waist,
    required this.bodyFat,
    required this.measurements,
  });

  int get feelingsCount => feelings.values.fold(0, (a, b) => a + b);

  /// Ressenti le plus fréquent (`null` sans ressenti ; en cas d'égalité, le plus difficile l'emporte).
  Ressenti? get dominantFeeling {
    if (feelingsCount == 0) return null;
    Ressenti? best;
    for (final r in Ressenti.values) {
      if (best == null || (feelings[r] ?? 0) >= (feelings[best] ?? 0)) best = r;
    }
    return best;
  }
}

/// Calcule le bilan de [program] à partir des séances et des mesures de l'élève.
///
/// - Séances prises en compte : celles dont la date tombe dans le programme.
/// - Poids / taille / masse grasse « début » : dernière mesure faite au plus tard
///   le premier jour (sinon la première mesure de la période) ; « fin » : dernière
///   mesure de la période. Il faut 2 mesures distinctes pour afficher un écart.
ProgramReport programReport({
  required Program program,
  required List<SessionModel> sessions,
  required List<Measurement> measurements,
  required DateTime now,
}) {
  final start = startOfDay(program.startDate);
  final end = program.endDate; // exclusif
  final status = programStatus(program, now);
  final periodEnd = now.isBefore(end) ? now : end;

  final inProgram = sessions.where((s) => !s.date.isBefore(start) && s.date.isBefore(end)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final done = inProgram.where((s) => s.isDone).length;
  final missed = inProgram.where((s) => !s.isDone && s.date.isBefore(now)).length;
  final upcoming = inProgram.where((s) => !s.isDone && !s.date.isBefore(now)).length;
  final due = done + missed;

  final weeks = <WeekReport>[
    for (var w = 0; w < program.weeks; w++)
      () {
        final ws = addDays(start, w * 7);
        final we = addDays(start, (w + 1) * 7);
        final list = inProgram.where((s) => !s.date.isBefore(ws) && s.date.isBefore(we));
        return WeekReport(
          week: w + 1,
          start: ws,
          planned: list.length,
          done: list.where((s) => s.isDone).length,
          missed: list.where((s) => !s.isDone && s.date.isBefore(now)).length,
        );
      }(),
  ];

  final feelings = <Ressenti, int>{for (final r in Ressenti.values) r: 0};
  for (final s in inProgram) {
    final f = s.feedback;
    if (s.isDone && f != null) feelings[f.ressenti] = feelings[f.ressenti]! + 1;
  }

  final sortedMeasures = sortedByDate(measurements);
  final inPeriod = sortedMeasures.where((m) => !m.date.isBefore(start) && m.date.isBefore(end)).toList();
  final beforeStart = sortedMeasures.where((m) => m.date.isBefore(addDays(start, 1))).toList();

  MeasureDelta? deltaOf(num? Function(Measurement) pick) {
    final startCandidates = [...beforeStart.reversed, ...inPeriod];
    Measurement? first;
    for (final m in startCandidates) {
      if (pick(m) != null) {
        first = m;
        break;
      }
    }
    Measurement? last;
    for (final m in inPeriod.reversed) {
      if (pick(m) != null) {
        last = m;
        break;
      }
    }
    if (first == null || last == null || first.id == last.id || !last.date.isAfter(first.date)) return null;
    return MeasureDelta(pick(first)!, pick(last)!);
  }

  return ProgramReport(
    program: program,
    status: status,
    periodEnd: periodEnd,
    planned: inProgram.length,
    done: done,
    missed: missed,
    upcoming: upcoming,
    attendancePct: due == 0 ? null : (done * 100 / due).round(),
    weeks: weeks,
    feelings: feelings,
    weight: deltaOf((m) => m.weightKg),
    waist: deltaOf((m) => m.waistCm),
    bodyFat: deltaOf((m) => m.bodyFatPct),
    measurements: [
      // Dernière mesure ANTÉRIEURE au programme : point de départ de la courbe.
      ...sortedMeasures.where((m) => m.date.isBefore(start)).toList().reversed.take(1),
      ...inPeriod,
    ],
  );
}
