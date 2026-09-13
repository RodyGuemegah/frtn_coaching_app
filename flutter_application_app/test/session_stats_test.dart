import 'package:flutter_application_app/models/session_model.dart';
import 'package:flutter_application_app/utils/session_stats.dart';
import 'package:flutter_test/flutter_test.dart';

SessionModel _s(String id, DateTime date, {bool done = false}) => SessionModel(
  id: id,
  title: id,
  status: done ? 'done' : 'todo',
  date: date,
  exercises: const [],
);

void main() {
  // Mercredi 16 septembre 2026, 10h00.
  final now = DateTime(2026, 9, 16, 10);

  group('nextSession', () {
    test('ignore les séances manquées du passé', () {
      final list = [_s('hier', DateTime(2026, 9, 15, 18)), _s('demain', DateTime(2026, 9, 17, 18))];
      expect(nextSession(list, now)?.id, 'demain');
    });

    test("inclut une séance d'aujourd'hui même si l'heure est passée", () {
      final list = [_s('ce-matin', DateTime(2026, 9, 16, 7)), _s('demain', DateTime(2026, 9, 17, 18))];
      expect(nextSession(list, now)?.id, 'ce-matin');
    });

    test('saute les séances déjà faites', () {
      final list = [_s('faite', DateTime(2026, 9, 17), done: true), _s('todo', DateTime(2026, 9, 18))];
      expect(nextSession(list, now)?.id, 'todo');
    });

    test('null sans séance à venir', () {
      expect(nextSession([_s('hier', DateTime(2026, 9, 15))], now), isNull);
    });
  });

  group('weekCount', () {
    test('inclut lundi 00:00 et exclut le lundi suivant', () {
      final list = [
        _s('lundi-minuit', DateTime(2026, 9, 14), done: true),
        _s('dimanche', DateTime(2026, 9, 20, 23, 59)),
        _s('lundi-suivant', DateTime(2026, 9, 21)),
        _s('semaine-passee', DateTime(2026, 9, 13, 12), done: true),
      ];
      final r = weekCount(list, now);
      expect(r.total, 2);
      expect(r.done, 1);
    });
  });

  group('monthAttendancePct', () {
    test('null sans séance passée ce mois-ci', () {
      expect(monthAttendancePct([_s('futur', DateTime(2026, 9, 20))], now), isNull);
    });

    test('ratio faites / passées', () {
      final list = [
        _s('a', DateTime(2026, 9, 1), done: true),
        _s('b', DateTime(2026, 9, 3), done: true),
        _s('c', DateTime(2026, 9, 5)),
        _s('d', DateTime(2026, 9, 8), done: true),
        _s('futur', DateTime(2026, 9, 25)),
        _s('mois-dernier', DateTime(2026, 8, 30)),
      ];
      expect(monthAttendancePct(list, now), 75);
    });
  });

  test('totalDone', () {
    expect(totalDone([_s('a', now, done: true), _s('b', now), _s('c', now, done: true)]), 2);
  });
}
