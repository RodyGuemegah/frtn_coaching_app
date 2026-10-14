import 'package:flutter_application_app/models/program.dart';
import 'package:flutter_application_app/utils/program_stats.dart';
import 'package:flutter_test/flutter_test.dart';

Program _p(String id, DateTime start, int weeks, {String title = 'Prise de masse'}) =>
    Program(id: id, title: title, startDate: start, weeks: weeks);

void main() {
  final now = DateTime(2026, 10, 14, 15); // mercredi 14/10, 15h

  group('dates', () {
    final p = _p('a', DateTime(2026, 9, 2), 12); // 12 semaines depuis le 02/09

    test('endDate = début + 12×7 jours, lastDay la veille', () {
      expect(p.endDate, DateTime(2026, 11, 25));
      expect(p.lastDay, DateTime(2026, 11, 24));
    });

    test('semaine en cours, avancement et jours restants', () {
      expect(programStatus(p, now), ProgramStatus.active);
      expect(currentWeek(p, now), 7); // 42 jours écoulés → semaine 7
      expect(programProgress(p, now), closeTo(42 / 84, 1e-9));
      expect(daysLeft(p, now), 42);
      expect(programWeekLabel(p, now), 'Semaine 7/12');
    });

    test('le jour de début = semaine 1 ; le lendemain de la fin = terminé', () {
      expect(currentWeek(p, DateTime(2026, 9, 2)), 1);
      expect(programStatus(p, DateTime(2026, 11, 24)), ProgramStatus.active);
      expect(programStatus(p, DateTime(2026, 11, 25)), ProgramStatus.finished);
      expect(programWeekLabel(p, DateTime(2026, 12, 1)), 'Terminé');
    });

    test('à venir', () {
      final future = _p('f', DateTime(2026, 10, 20), 8);
      expect(programStatus(future, now), ProgramStatus.upcoming);
      expect(programWeekLabel(future, now), 'Commence le 20/10');
      expect(programProgress(future, now), 0);
    });
  });

  group('currentProgram', () {
    test('privilégie le programme en cours', () {
      final list = [_p('old', DateTime(2026, 1, 1), 4), _p('now', DateTime(2026, 10, 1), 8), _p('next', DateTime(2026, 12, 1), 4)];
      expect(currentProgram(list, now)!.id, 'now');
    });

    test('sinon le prochain à venir, sinon le dernier terminé', () {
      expect(currentProgram([_p('old', DateTime(2026, 1, 1), 4), _p('next', DateTime(2026, 11, 1), 4)], now)!.id, 'next');
      expect(currentProgram([_p('a', DateTime(2026, 1, 1), 4), _p('b', DateTime(2026, 5, 1), 4)], now)!.id, 'b');
      expect(currentProgram(const [], now), isNull);
    });
  });

  group('needsRenewal', () {
    test('aucun programme → pas à renouveler', () {
      expect(needsRenewal(const [], now), isFalse);
    });

    test('se termine dans ≤ 7 jours sans suite → à renouveler', () {
      // fin le 20/10 → 6 jours restants
      expect(needsRenewal([_p('a', DateTime(2026, 9, 22), 4)], now), isTrue);
    });

    test('se termine dans plus de 7 jours → non', () {
      expect(needsRenewal([_p('a', DateTime(2026, 10, 1), 8)], now), isFalse);
    });

    test('terminé sans suite → à renouveler ; avec une suite prévue → non', () {
      final done = _p('a', DateTime(2026, 7, 1), 4);
      expect(needsRenewal([done], now), isTrue);
      expect(needsRenewal([done, _p('b', DateTime(2026, 10, 20), 4)], now), isFalse);
    });
  });

  group('renewalOf', () {
    test('Phase N → Phase N+1, même durée, démarre à la fin du précédent', () {
      final prev = _p('a', DateTime(2026, 9, 22), 4, title: 'Prise de masse — Phase 2');
      final next = renewalOf(prev, now);
      expect(next.title, 'Prise de masse — Phase 3');
      expect(next.weeks, 4);
      expect(next.startDate, DateTime(2026, 10, 20));
      expect(next.id, '');
    });

    test('titre sans phase → « — Phase 2 » ; programme déjà fini → démarre aujourd\'hui', () {
      final prev = _p('a', DateTime(2026, 6, 1), 4, title: 'Remise en forme');
      final next = renewalOf(prev, now);
      expect(next.title, 'Remise en forme — Phase 2');
      expect(next.startDate, DateTime(2026, 10, 14));
    });
  });

  test("jours restants justes au passage à l'heure d'été (29/03/2026)", () {
    // Du 20/03 au 03/04 : 14 jours, dont la nuit où l'on perd une heure.
    final p = _p('ete', DateTime(2026, 3, 20), 2);
    expect(daysLeft(p, DateTime(2026, 3, 20)), 14);
    expect(currentWeek(p, DateTime(2026, 3, 27)), 2);
  });
}
