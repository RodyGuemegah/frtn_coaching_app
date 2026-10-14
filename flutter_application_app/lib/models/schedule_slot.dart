import 'firestore_helpers.dart';

/// Type de créneau récurrent de l'emploi du temps.
enum SlotKind {
  cours('cours', 'Cours', '📚'),
  travail('travail', 'Travail', '💼'),
  sommeil('sommeil', 'Sommeil', '😴'),
  activite('activite', 'Activité', '🏃'),
  autre('autre', 'Autre', '📌');

  final String key;
  final String label;
  final String emoji;
  const SlotKind(this.key, this.label, this.emoji);

  static SlotKind fromKey(String? key) =>
      SlotKind.values.firstWhere((k) => k.key == key, orElse: () => SlotKind.autre);
}

/// Créneau qui se répète chaque semaine (ex : « Cours, lun→ven, 8h30–12h00 »).
/// Stocké dans `users/{uid}/schedule/{id}`.
class ScheduleSlot {
  final String id;
  final String title;
  final SlotKind kind;

  /// Jours de la semaine concernés : 1 = lundi … 7 = dimanche (comme `DateTime.weekday`).
  final List<int> weekdays;

  /// Heure de début, en minutes depuis minuit (510 = 8h30).
  final int startMinutes;

  /// Heure de fin, en minutes depuis minuit ; `null` = ponctuel (ex : « Coucher 23h00 »).
  final int? endMinutes;

  const ScheduleSlot({
    required this.id,
    required this.title,
    required this.kind,
    required this.weekdays,
    required this.startMinutes,
    this.endMinutes,
  });

  bool occursOn(DateTime day) => weekdays.contains(day.weekday);

  /// Date/heure de début de ce créneau pour un jour donné.
  DateTime startOn(DateTime day) => DateTime(day.year, day.month, day.day).add(Duration(minutes: startMinutes));

  DateTime? endOn(DateTime day) =>
      endMinutes == null ? null : DateTime(day.year, day.month, day.day).add(Duration(minutes: endMinutes!));

  factory ScheduleSlot.fromDoc(String id, Map<String, dynamic> m) {
    final days = (m['weekdays'] is List ? m['weekdays'] as List : const [])
        .map((d) => parseInt(d))
        .where((d) => d >= 1 && d <= 7)
        .toSet()
        .toList()
      ..sort();
    return ScheduleSlot(
      id: id,
      title: parseString(m['title']),
      kind: SlotKind.fromKey(parseStringOrNull(m['kind'])),
      weekdays: days,
      startMinutes: parseInt(m['startMinutes']).clamp(0, 24 * 60 - 1),
      endMinutes: parseIntOrNull(m['endMinutes']),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'kind': kind.key,
    'weekdays': (weekdays.toSet().toList()..sort()),
    'startMinutes': startMinutes,
    if (endMinutes != null) 'endMinutes': endMinutes,
  };
}

/// « 08h30 » à partir d'un nombre de minutes depuis minuit (même format que `formatTime`).
String formatMinutes(int minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}h${m.toString().padLeft(2, '0')}';
}

/// « Lun → Ven », « Lun, Mer, Ven », « Tous les jours ».
String formatWeekdays(List<int> days) {
  const names = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  final sorted = days.toSet().toList()..sort();
  if (sorted.length == 7) return 'Tous les jours';
  if (sorted.isEmpty) return 'Aucun jour';
  // Plage continue de 3 jours ou plus → « Lun → Ven ».
  final continuous = sorted.length >= 3 && sorted.last - sorted.first == sorted.length - 1;
  if (continuous) return '${names[sorted.first - 1]} → ${names[sorted.last - 1]}';
  return sorted.map((d) => names[d - 1]).join(', ');
}
