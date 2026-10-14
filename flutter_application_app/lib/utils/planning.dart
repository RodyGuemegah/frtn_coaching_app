import '../models/meal_model.dart';
import '../models/schedule_slot.dart';
import '../models/session_model.dart';
import 'format.dart';

/// Nature d'un élément de la frise.
enum PlanningKind { session, meal, slot }

/// Un élément de la frise d'une journée (séance, repas ou créneau récurrent).
class PlanningItem {
  final PlanningKind kind;
  final DateTime start;
  final DateTime? end;
  final String title;
  final String subtitle;
  final String emoji;

  /// Objet d'origine (SessionModel, MealModel ou ScheduleSlot) pour les actions au toucher.
  final Object source;

  const PlanningItem({
    required this.kind,
    required this.start,
    this.end,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.source,
  });

  /// « 8h30 – 12h00 » ou « 18h00 ».
  String get timeLabel => end == null ? formatTime(start) : '${formatTime(start)} – ${formatTime(end!)}';
}

/// Assemble la journée [day] : séances et repas datés de ce jour + créneaux récurrents
/// qui tombent ce jour-là, triés par heure de début.
List<PlanningItem> buildDayItems({
  required DateTime day,
  required List<SessionModel> sessions,
  required List<MealModel> meals,
  required List<ScheduleSlot> slots,
}) {
  final items = <PlanningItem>[
    for (final s in sessions.where((s) => isSameDay(s.date, day)))
      PlanningItem(
        kind: PlanningKind.session,
        start: s.date,
        end: s.durationMin == null ? null : s.date.add(Duration(minutes: s.durationMin!)),
        title: 'Séance : ${s.title}',
        subtitle: [
          '${s.exercises.length} exercice${s.exercises.length > 1 ? 's' : ''}',
          if (s.isDone) 'faite ✓',
        ].join(' · '),
        emoji: '💪',
        source: s,
      ),
    for (final m in meals.where((m) => isSameDay(m.date, day)))
      PlanningItem(
        kind: PlanningKind.meal,
        start: m.date,
        title: m.title,
        subtitle: [if (m.kcal > 0) '${m.kcal} kcal', if (m.eaten) 'mangé ✓'].join(' · '),
        emoji: mealEmoji(m.title),
        source: m,
      ),
    for (final sl in slots.where((sl) => sl.occursOn(day)))
      PlanningItem(
        kind: PlanningKind.slot,
        start: sl.startOn(day),
        end: sl.endOn(day),
        title: sl.title.isEmpty ? sl.kind.label : sl.title,
        // Pas de « Cours · Cours » : le type n'est rappelé que s'il diffère de l'intitulé.
        subtitle: (sl.title.isEmpty || sl.title == sl.kind.label) ? '' : sl.kind.label,
        emoji: sl.kind.emoji,
        source: sl,
      ),
  ];
  items.sort((a, b) {
    final byTime = a.start.compareTo(b.start);
    if (byTime != 0) return byTime;
    // À heure égale : créneau, puis repas, puis séance.
    return b.kind.index.compareTo(a.kind.index);
  });
  return items;
}
