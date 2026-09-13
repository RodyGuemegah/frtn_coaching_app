import 'package:cloud_firestore/cloud_firestore.dart';

/// Helpers de parsing tolérants pour les documents Firestore.
/// Un champ absent ou mal typé ne doit jamais faire planter un stream entier.

DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}

int parseInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

int? parseIntOrNull(dynamic v) => v == null ? null : parseInt(v);

num parseNum(dynamic v, [num fallback = 0]) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim()) ?? fallback;
  return fallback;
}

num? parseNumOrNull(dynamic v) => v == null ? null : parseNum(v);

String parseString(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();

String? parseStringOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

Map<String, dynamic> parseMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return <String, dynamic>{};
}

List<Map<String, dynamic>> parseMapList(dynamic v) {
  if (v is! List) return const [];
  return v.whereType<Map>().map(parseMap).toList();
}
