import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_app/models/session_model.dart';
import 'package:flutter_application_app/models/session_template.dart';
import 'package:flutter_test/flutter_test.dart';

// Deux exercices réutilisés dans plusieurs tests.
const _dc = Exercise(name: 'Développé couché barre', sets: 4, reps: 6, load: 60, restSec: 120);
const _tractions = Exercise(name: 'Tractions pronation', sets: 4, reps: 8, load: 0, restSec: 90);

/// Un modèle complet (tous les champs remplis).
const _template = SessionTemplate(
  id: 'tpl1',
  title: 'Haut du corps — Force',
  durationMin: 55,
  coachNote: 'Concentre-toi sur la technique',
  exercises: [_dc, _tractions],
);

void main() {
  group('Lecture depuis Firestore (fromDoc)', () {
    test('lit tous les champs d\'un document complet', () {
      final doc = {
        'title': 'Haut du corps — Force',
        'durationMin': 55,
        'coachNote': 'Concentre-toi sur la technique',
        'exercises': [_dc.toMap(), _tractions.toMap()],
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 5, 9)),
      };

      final t = SessionTemplate.fromDoc('tpl1', doc);

      expect(t.id, 'tpl1');
      expect(t.title, 'Haut du corps — Force');
      expect(t.durationMin, 55);
      expect(t.coachNote, 'Concentre-toi sur la technique');
      expect(t.exercises.length, 2);
      expect(t.exercises.first.name, 'Développé couché barre');
      expect(t.exercises.first.load, 60);
      expect(t.createdAt, DateTime(2026, 10, 5, 9));
    });

    test('tolère un document incomplet sans planter', () {
      // Seul le titre est présent : les champs optionnels doivent rester null / vides.
      final t = SessionTemplate.fromDoc('tpl2', {'title': 'Cardio'});

      expect(t.title, 'Cardio');
      expect(t.durationMin, isNull);
      expect(t.coachNote, isNull);
      expect(t.exercises, isEmpty);
      expect(t.createdAt, isNull);
    });
  });

  group('Écriture vers Firestore (toMap)', () {
    test('n\'écrit pas les champs optionnels vides', () {
      const t = SessionTemplate(id: 'x', title: 'Cardio', exercises: []);
      final map = t.toMap();

      expect(map.containsKey('durationMin'), isFalse);
      expect(map.containsKey('coachNote'), isFalse);
      expect(map.containsKey('createdAt'), isFalse, reason: 'createdAt est posé par le service');
      expect(map['title'], 'Cardio');
    });

    test('aller-retour : toMap puis fromDoc redonne le même modèle', () {
      final relu = SessionTemplate.fromDoc('tpl1', _template.toMap());

      expect(relu.title, _template.title);
      expect(relu.durationMin, _template.durationMin);
      expect(relu.coachNote, _template.coachNote);
      expect(relu.exercises.map((e) => e.label), _template.exercises.map((e) => e.label));
    });
  });

  group('Séance → modèle (fromSession)', () {
    test('garde le contenu mais oublie l\'élève, la date et le statut', () {
      final seance = SessionModel(
        id: 's1',
        title: 'Jambes',
        status: 'done',
        date: DateTime(2026, 10, 1, 18),
        durationMin: 60,
        exercises: const [_dc],
        studentId: 'lucas',
        coachId: 'coach',
      );

      final t = SessionTemplate.fromSession(seance);

      expect(t.id, '', reason: 'un nouvel id sera attribué par Firestore');
      expect(t.title, 'Jambes');
      expect(t.durationMin, 60);
      expect(t.exercises.single.name, 'Développé couché barre');
    });
  });

  group('Modèle → séance (toSession)', () {
    final date = DateTime(2026, 10, 7, 18, 30);
    SessionModel creerSeance() => _template.toSession(
          studentId: 'lucas',
          coachId: 'coach',
          coachName: 'Rodney Guemegah',
          date: date,
        );

    test('crée une séance « à faire » pour le bon élève, à la bonne date', () {
      final s = creerSeance();

      expect(s.id, '');
      expect(s.status, 'todo');
      expect(s.isDone, isFalse);
      expect(s.date, date);
      expect(s.studentId, 'lucas');
      expect(s.coachId, 'coach');
      expect(s.coachName, 'Rodney Guemegah');
      expect(s.feedback, isNull);
    });

    test('reprend le contenu du modèle', () {
      final s = creerSeance();

      expect(s.title, _template.title);
      expect(s.durationMin, 55);
      expect(s.coachNote, _template.coachNote);
      expect(s.exercises.length, 2);
    });

    test('la séance a sa propre copie des exercices', () {
      final s = creerSeance();

      // Si la liste était partagée, modifier la séance modifierait aussi le modèle.
      expect(identical(s.exercises, _template.exercises), isFalse);
    });
  });
}
