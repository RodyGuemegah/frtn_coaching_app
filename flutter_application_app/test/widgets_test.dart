import 'package:flutter/material.dart';
import 'package:flutter_application_app/models/session_model.dart';
import 'package:flutter_application_app/widgets/cartes.dart';
import 'package:flutter_application_app/widgets/tags.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('StatTile affiche valeur et libellé', (tester) async {
    await tester.pumpWidget(_wrap(const StatTile(value: '3/5', label: 'Séances cette semaine')));
    expect(find.text('3/5'), findsOneWidget);
    expect(find.text('Séances cette semaine'), findsOneWidget);
  });

  testWidgets('TagChip et ErrorCard', (tester) async {
    var retried = false;
    await tester.pumpWidget(_wrap(Column(
      children: [
        const TagChip("Aujourd'hui · 18h00", style: TagStyle.today),
        ErrorCard(message: 'Oups', onRetry: () => retried = true),
      ],
    )));
    expect(find.text("Aujourd'hui · 18h00"), findsOneWidget);
    expect(find.text('Oups'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    expect(retried, isTrue);
  });

  testWidgets('PrimaryButton désactivé ne déclenche rien', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(Column(
      children: [
        PrimaryButton(label: 'ok', onPressed: () => tapped = true),
        const PrimaryButton(label: 'off', onPressed: null),
      ],
    )));
    await tester.tap(find.text('OFF'));
    expect(tapped, isFalse);
    await tester.tap(find.text('OK'));
    expect(tapped, isTrue);
  });

  test('Exercise.label', () {
    expect(const Exercise(name: 'DC', sets: 4, reps: 6, load: 60, restSec: 120).label, '4 × 6 reps · 60 kg · repos 2 min');
    expect(const Exercise(name: 'Tractions', sets: 4, reps: 8, load: 0, restSec: 90).label, '4 × 8 reps · PDC · repos 90s');
    expect(const Exercise(name: 'Curl', sets: 3, reps: 12, load: 12.5, restSec: 0).label, '3 × 12 reps · 12.5 kg');
  });
}
