import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_helpers.dart';

/// Une prise de mesures (pesée…) d'un élève.
/// Stockée dans `users/{uid}/measurements/{id}`.
class Measurement {
  final String id;
  final DateTime date;
  final num weightKg;
  final num? waistCm;
  final num? bodyFatPct;
  final String? note;

  const Measurement({
    required this.id,
    required this.date,
    required this.weightKg,
    this.waistCm,
    this.bodyFatPct,
    this.note,
  });

  factory Measurement.fromDoc(String id, Map<String, dynamic> m) => Measurement(
    id: id,
    date: parseDate(m['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    weightKg: parseNum(m['weightKg']),
    waistCm: parseNumOrNull(m['waistCm']),
    bodyFatPct: parseNumOrNull(m['bodyFatPct']),
    note: parseStringOrNull(m['note']),
  );

  /// Champs persistés (sans `createdAt`, posé par le service).
  Map<String, dynamic> toMap() => {
    'date': Timestamp.fromDate(date),
    'weightKg': weightKg,
    if (waistCm != null) 'waistCm': waistCm,
    if (bodyFatPct != null) 'bodyFatPct': bodyFatPct,
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
  };
}

/// « 71,2 » — nombre à la française, 1 décimale max, sans « ,0 ».
String formatKg(num v) {
  final rounded = (v * 10).round() / 10;
  final s = rounded % 1 == 0 ? rounded.toInt().toString() : rounded.toStringAsFixed(1);
  return s.replaceAll('.', ',');
}

/// « +1,8 kg » / « −0,6 kg » / « = 0 kg ».
String formatDeltaKg(num delta) {
  final r = (delta * 10).round() / 10;
  if (r == 0) return '= 0 kg';
  return '${r > 0 ? '+' : '−'}${formatKg(r.abs())} kg';
}
