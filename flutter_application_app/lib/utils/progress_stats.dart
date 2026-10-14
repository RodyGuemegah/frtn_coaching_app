import '../models/measurement.dart';

/// Résumé de progression calculé à partir des mesures (pur, testable).
class ProgressSummary {
  final Measurement? first;
  final Measurement? latest;

  /// Écart de poids entre la première et la dernière mesure.
  final num? totalDeltaKg;

  /// Écart de poids sur les 30 derniers jours (dernière mesure − mesure la plus proche d'il y a 30 j).
  final num? last30DaysDeltaKg;

  const ProgressSummary({this.first, this.latest, this.totalDeltaKg, this.last30DaysDeltaKg});

  bool get isEmpty => latest == null;
}

/// Trie les mesures par date croissante (copie).
List<Measurement> sortedByDate(List<Measurement> list) => List.of(list)..sort((a, b) => a.date.compareTo(b.date));

ProgressSummary progressSummary(List<Measurement> measurements, DateTime now) {
  final sorted = sortedByDate(measurements);
  if (sorted.isEmpty) return const ProgressSummary();
  final first = sorted.first;
  final latest = sorted.last;

  // Référence à ~30 jours : dernière mesure faite au plus tard il y a 30 jours.
  final cutoff = now.subtract(const Duration(days: 30));
  final before = sorted.where((m) => !m.date.isAfter(cutoff)).toList();
  final ref30 = before.isEmpty ? null : before.last;

  return ProgressSummary(
    first: first,
    latest: latest,
    totalDeltaKg: sorted.length < 2 ? null : latest.weightKg - first.weightKg,
    last30DaysDeltaKg: ref30 == null || ref30.id == latest.id ? null : latest.weightKg - ref30.weightKg,
  );
}

/// Écart avec la mesure précédente (dans l'ordre chronologique), `null` pour la première.
Map<String, num> deltasWithPrevious(List<Measurement> measurements) {
  final sorted = sortedByDate(measurements);
  return {
    for (var i = 1; i < sorted.length; i++) sorted[i].id: sorted[i].weightKg - sorted[i - 1].weightKg,
  };
}

/// Période d'affichage du graphique.
enum ChartRange {
  month('1 mois', 31),
  quarter('3 mois', 92),
  all('Tout', null);

  final String label;
  final int? days;
  const ChartRange(this.label, this.days);
}

/// Mesures à afficher pour une période (triées). Si la période contient moins
/// de 2 points, on élargit à tout l'historique pour garder une courbe lisible.
List<Measurement> measurementsInRange(List<Measurement> measurements, ChartRange range, DateTime now) {
  final sorted = sortedByDate(measurements);
  if (range.days == null) return sorted;
  final from = now.subtract(Duration(days: range.days!));
  final inRange = sorted.where((m) => !m.date.isBefore(from)).toList();
  return inRange.length >= 2 ? inRange : sorted;
}

/// La mesure [candidate] est-elle (au moins aussi) récente que toutes les autres ?
bool isLatest(Measurement candidate, List<Measurement> others) =>
    others.where((m) => m.id != candidate.id).every((m) => !m.date.isAfter(candidate.date));
