import 'package:flutter_application_app/models/meal_model.dart';
import 'package:flutter_application_app/models/schedule_slot.dart';
import 'package:flutter_application_app/models/session_model.dart';
import 'package:flutter_application_app/utils/planning.dart';
import 'package:flutter_test/flutter_test.dart';

// Mardi 14 octobre 2026.
final _tuesday = DateTime(2026, 10, 14);

const _cours = ScheduleSlot(
  id: 'c',
  title: 'Cours',
  kind: SlotKind.cours,
  weekdays: [1, 2, 3, 4, 5],
  startMinutes: 8 * 60 + 30,
  endMinutes: 12 * 60,
);
const _coucher = ScheduleSlot(id: 'z', title: 'Coucher', kind: SlotKind.sommeil, weekdays: [1, 2, 3, 4, 5, 6, 7], startMinutes: 23 * 60);
const _weekend = ScheduleSlot(id: 'w', title: 'Foot', kind: SlotKind.activite, weekdays: [6, 7], startMinutes: 10 * 60);

void main() {
  group('ScheduleSlot', () {
    test('occursOn suit les jours de la semaine', () {
      expect(_cours.occursOn(_tuesday), isTrue);
      expect(_weekend.occursOn(_tuesday), isFalse);
      expect(_weekend.occursOn(DateTime(2026, 10, 17)), isTrue); // samedi
    });

    test('startOn / endOn placent le créneau à la bonne heure du jour', () {
      expect(_cours.startOn(_tuesday), DateTime(2026, 10, 14, 8, 30));
      expect(_cours.endOn(_tuesday), DateTime(2026, 10, 14, 12));
      expect(_coucher.endOn(_tuesday), isNull);
    });

    test('fromDoc nettoie les jours (doublons, hors 1..7) et trie', () {
      final s = ScheduleSlot.fromDoc('x', {
        'title': 'Cours',
        'kind': 'cours',
        'weekdays': [5, 1, 1, 9, 0, 3],
        'startMinutes': 510,
      });
      expect(s.weekdays, [1, 3, 5]);
      expect(s.kind, SlotKind.cours);
      expect(s.endMinutes, isNull);
    });

    test('type inconnu → « Autre »', () {
      expect(SlotKind.fromKey('piscine'), SlotKind.autre);
    });
  });

  group('formatage', () {
    test('formatMinutes', () {
      expect(formatMinutes(510), '08h30');
      expect(formatMinutes(23 * 60), '23h00');
    });

    test('formatWeekdays', () {
      expect(formatWeekdays([1, 2, 3, 4, 5]), 'Lun → Ven');
      expect(formatWeekdays([1, 3, 5]), 'Lun, Mer, Ven');
      expect(formatWeekdays([6, 7]), 'Sam, Dim');
      expect(formatWeekdays([1, 2, 3, 4, 5, 6, 7]), 'Tous les jours');
    });
  });

  test('buildDayItems assemble et trie séances, repas et créneaux du jour', () {
    final sessions = [
      SessionModel(id: 's1', title: 'Haut du corps', status: 'todo', date: DateTime(2026, 10, 14, 18), exercises: const [], durationMin: 60),
      SessionModel(id: 's2', title: 'Autre jour', status: 'todo', date: DateTime(2026, 10, 15, 18), exercises: const []),
    ];
    final meals = [
      MealModel(id: 'm1', title: 'Déjeuner', time: '12h30', date: DateTime(2026, 10, 14, 12, 30), kcal: 720, protein: 48, carbs: 74, fat: 22, eaten: true),
      MealModel(id: 'm2', title: 'Petit-déjeuner', time: '7h30', date: DateTime(2026, 10, 14, 7, 30), kcal: 610, protein: 34, carbs: 68, fat: 20, eaten: false),
    ];

    final items = buildDayItems(day: _tuesday, sessions: sessions, meals: meals, slots: const [_cours, _coucher, _weekend]);

    expect(items.map((i) => i.title).toList(), [
      'Petit-déjeuner', // 7h30
      'Cours', // 8h30
      'Déjeuner', // 12h30
      'Séance : Haut du corps', // 18h00
      'Coucher', // 23h00
    ]);
    expect(items[3].kind, PlanningKind.session);
    expect(items[3].timeLabel, '18h00 – 19h00', reason: 'fin calculée depuis la durée');
    expect(items[1].timeLabel, '08h30 – 12h00');
    expect(items[2].subtitle, contains('mangé ✓'));
  });
}
