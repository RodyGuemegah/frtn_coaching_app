import '../models/program.dart';
import 'format.dart';
import 'session_stats.dart';

enum ProgramStatus { upcoming, active, finished }

/// Nombre de jours avant la fin à partir duquel un programme est « à renouveler ».
const renewalThresholdDays = 7;

ProgramStatus programStatus(Program p, DateTime now) {
  final today = startOfDay(now);
  if (today.isBefore(startOfDay(p.startDate))) return ProgramStatus.upcoming;
  if (!today.isBefore(p.endDate)) return ProgramStatus.finished;
  return ProgramStatus.active;
}

/// Semaine en cours (1 à [Program.weeks]) ; bornée hors de la période.
int currentWeek(Program p, DateTime now) {
  final days = daysBetween(p.startDate, now);
  return (days ~/ 7 + 1).clamp(1, p.weeks);
}

/// Avancement de 0 à 1 (au jour près).
double programProgress(Program p, DateTime now) {
  final total = p.weeks * 7;
  final elapsed = daysBetween(p.startDate, now);
  return (elapsed / total).clamp(0.0, 1.0);
}

/// Jours restants avant la fin (0 si terminé).
int daysLeft(Program p, DateTime now) {
  final d = daysBetween(now, p.endDate);
  return d < 0 ? 0 : d;
}

/// Programme « courant » d'un élève : celui en cours ; sinon le prochain à venir ;
/// sinon le dernier terminé. `null` s'il n'en a aucun.
Program? currentProgram(List<Program> programs, DateTime now) {
  if (programs.isEmpty) return null;
  final byStart = List.of(programs)..sort((a, b) => a.startDate.compareTo(b.startDate));
  final active = byStart.where((p) => programStatus(p, now) == ProgramStatus.active).toList();
  if (active.isNotEmpty) return active.last;
  final upcoming = byStart.where((p) => programStatus(p, now) == ProgramStatus.upcoming).toList();
  if (upcoming.isNotEmpty) return upcoming.first;
  return byStart.last;
}

/// L'élève a-t-il un programme à renouveler ?
/// - son programme en cours se termine dans moins de [renewalThresholdDays] jours
///   ET aucun programme suivant n'est prévu ; ou
/// - son dernier programme est terminé et rien n'a été prévu depuis.
/// Un élève sans aucun programme n'est PAS « à renouveler ».
bool needsRenewal(List<Program> programs, DateTime now) {
  if (programs.isEmpty) return false;
  final hasUpcoming = programs.any((p) => programStatus(p, now) == ProgramStatus.upcoming);
  if (hasUpcoming) return false;
  final current = currentProgram(programs, now)!;
  final status = programStatus(current, now);
  if (status == ProgramStatus.finished) return true;
  return status == ProgramStatus.active && daysLeft(current, now) <= renewalThresholdDays;
}

/// « Semaine 6/12 », « Commence le 20/10 », « Terminé ».
String programWeekLabel(Program p, DateTime now) {
  switch (programStatus(p, now)) {
    case ProgramStatus.active:
      return 'Semaine ${currentWeek(p, now)}/${p.weeks}';
    case ProgramStatus.upcoming:
      final d = startOfDay(p.startDate);
      return 'Commence le ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    case ProgramStatus.finished:
      return 'Terminé';
  }
}

/// Proposition de programme suivant (bouton « Renouveler ») :
/// même durée et objectif, démarre à la fin du précédent (ou aujourd'hui s'il est déjà fini),
/// titre « … — Phase N+1 » si le titre suit ce schéma.
Program renewalOf(Program previous, DateTime now) {
  final today = startOfDay(now);
  final start = previous.endDate.isBefore(today) ? today : previous.endDate;
  final phase = RegExp(r'^(.*?)(?:\s*[—–-]\s*)?Phase\s+(\d+)\s*$', caseSensitive: false).firstMatch(previous.title);
  final title = phase != null
      ? '${phase.group(1)!.trim()} — Phase ${int.parse(phase.group(2)!) + 1}'
      : '${previous.title} — Phase 2';
  return Program(
    id: '',
    title: title,
    goal: previous.goal,
    startDate: start,
    weeks: previous.weeks,
    studentId: previous.studentId,
    coachId: previous.coachId,
  );
}
