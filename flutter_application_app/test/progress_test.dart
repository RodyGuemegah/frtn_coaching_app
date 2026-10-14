import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_app/models/measurement.dart';
import 'package:flutter_application_app/utils/progress_stats.dart';
import 'package:flutter_test/flutter_test.dart';

Measurement _m(String id, DateTime d, num kg) => Measurement(id: id, date: d, weightKg: kg);

void main() {
  final now = DateTime(2026, 10, 14);
  // Volontairement dans le désordre : les calculs doivent trier eux-mêmes.
  final data = [
    _m('c', DateTime(2026, 9, 1), 70.1),
    _m('a', DateTime(2026, 2, 1), 69.4),
    _m('e', DateTime(2026, 10, 12), 71.2),
    _m('d', DateTime(2026, 9, 20), 70.8),
  ];

  group('formatage', () {
    test('formatKg : virgule, 1 décimale, pas de « ,0 »', () {
      expect(formatKg(71.2), '71,2');
      expect(formatKg(70), '70');
      expect(formatKg(70.04), '70');
      expect(formatKg(69.96), '70');
    });

    test('formatDeltaKg : signe et arrondi', () {
      expect(formatDeltaKg(1.8), '+1,8 kg');
      expect(formatDeltaKg(-0.6), '−0,6 kg');
      expect(formatDeltaKg(0.02), '= 0 kg');
    });
  });

  test('progressSummary : première, dernière et évolutions', () {
    final s = progressSummary(data, now);
    expect(s.first!.id, 'a');
    expect(s.latest!.id, 'e');
    expect(s.totalDeltaKg, closeTo(1.8, 1e-9));
    // Référence 30 jours = dernière mesure au plus tard le 14/09 → « c » (70,1) ; 71,2 − 70,1 = 1,1
    expect(s.last30DaysDeltaKg, closeTo(1.1, 1e-9));
  });

  test('progressSummary : une seule mesure → pas d\'évolution', () {
    final s = progressSummary([_m('x', now, 70)], now);
    expect(s.isEmpty, isFalse);
    expect(s.totalDeltaKg, isNull);
    expect(s.last30DaysDeltaKg, isNull);
  });

  test('progressSummary : aucune mesure', () {
    expect(progressSummary(const [], now).isEmpty, isTrue);
  });

  test('deltasWithPrevious : écart avec la mesure précédente dans le temps', () {
    final d = deltasWithPrevious(data);
    expect(d.containsKey('a'), isFalse, reason: 'la première n\'a pas de précédente');
    expect(d['c'], closeTo(0.7, 1e-9));
    expect(d['d'], closeTo(0.7, 1e-9));
    expect(d['e'], closeTo(0.4, 1e-9));
  });

  group('measurementsInRange', () {
    test('« 1 mois » garde les mesures récentes', () {
      final r = measurementsInRange(data, ChartRange.month, now);
      expect(r.map((m) => m.id), ['d', 'e']);
    });

    test('moins de 2 points dans la période → tout l\'historique', () {
      final r = measurementsInRange([_m('old', DateTime(2025, 1, 1), 68), _m('new', now, 70)], ChartRange.month, now);
      expect(r.length, 2);
    });
  });

  test('isLatest : la nouvelle mesure est-elle la plus récente ?', () {
    expect(isLatest(_m('', now, 71), data), isTrue);
    expect(isLatest(_m('', DateTime(2026, 9, 10), 70), data), isFalse);
    // En édition, la mesure ne se compare pas à elle-même.
    expect(isLatest(_m('e', DateTime(2026, 10, 12), 71.5), data), isTrue);
  });

  test('Measurement.fromDoc / toMap', () {
    final m = Measurement.fromDoc('x', {
      'date': Timestamp.fromDate(DateTime(2026, 10, 1)),
      'weightKg': 71.2,
      'waistCm': 82,
    });
    expect(m.weightKg, 71.2);
    expect(m.waistCm, 82);
    expect(m.bodyFatPct, isNull);
    final map = m.toMap();
    expect(map.containsKey('bodyFatPct'), isFalse);
    expect(map.containsKey('note'), isFalse);
  });
}
