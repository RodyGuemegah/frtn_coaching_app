import 'package:flutter/material.dart';
import 'package:flutter_application_app/models/app_user.dart';
import 'package:flutter_application_app/models/session_model.dart';
import 'package:flutter_application_app/screens/coach/coach_create_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dupliquer : contenu copié, même heure une semaine plus tard, élève présélectionné', (tester) async {
    const lucas = AppUser(uid: 'lucas', email: 'l@t.fr', displayName: 'Lucas Martin');
    const emma = AppUser(uid: 'emma', email: 'e@t.fr', displayName: 'Emma Bertrand');
    final source = SessionModel(
      id: 's1',
      title: 'Haut du corps — Force',
      status: 'done', // une séance faite peut être dupliquée : la copie repart « à faire »
      date: DateTime(2026, 10, 15, 18), // jeudi 15/10 18h00
      durationMin: 55,
      coachNote: 'Technique avant tout',
      exercises: const [Exercise(name: 'Développé couché', sets: 4, reps: 6, load: 60, restSec: 120)],
      studentId: 'lucas',
      coachId: 'coach',
    );

    // Écran virtuel haut : tout le formulaire est construit (la liste est paresseuse).
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CoachCreateSessionForm(students: const [lucas, emma], prefill: source)),
    ));

    expect(find.text('Haut du corps — Force'), findsOneWidget);
    expect(find.text('Développé couché'), findsOneWidget);
    expect(find.text('Technique avant tout'), findsOneWidget);
    // « 55 » est aussi l'exemple grisé du champ : on vérifie la valeur saisie.
    expect(find.byWidgetPredicate((w) => w is EditableText && w.controller.text == '55'), findsOneWidget);
    expect(find.text('Jeu. 22 octobre'), findsOneWidget, reason: 'date + 7 jours');
    expect(find.text('18h00'), findsOneWidget, reason: 'même heure');
    expect(find.text('Lucas Martin'), findsOneWidget, reason: 'élève présélectionné');
    // Duplication = création : le bouton n'est pas « Enregistrer les modifications ».
    expect(find.text('📤 ASSIGNER LA SÉANCE'), findsOneWidget);
  });
}
