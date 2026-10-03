import 'package:flutter_application_app/models/meal_model.dart';
import 'package:flutter_test/flutter_test.dart';

MealModel _m(int kcal, int p, int c, int f, {DateTime? date, bool eaten = false}) => MealModel(
  id: 'x',
  title: 'Déjeuner',
  time: '12h30',
  date: date ?? DateTime(2026, 10, 3, 12, 30),
  kcal: kcal,
  protein: p,
  carbs: c,
  fat: f,
  eaten: eaten,
);

void main() {
  test('mealTotals additionne kcal et macros', () {
    final t = mealTotals([_m(610, 34, 68, 20), _m(720, 48, 74, 22)]);
    expect(t.kcal, 1330);
    expect(t.protein, 82);
    expect(t.carbs, 142);
    expect(t.fat, 42);
  });

  test('kcalFromMacros applique 4/4/9', () {
    expect(kcalFromMacros(48, 74, 22), 48 * 4 + 74 * 4 + 22 * 9);
  });

  test('copyToDay garde l\'heure, change le jour et décoche', () {
    final copy = _m(500, 30, 50, 10, eaten: true).copyToDay(DateTime(2026, 10, 7));
    expect(copy.date, DateTime(2026, 10, 7, 12, 30));
    expect(copy.eaten, isFalse);
    expect(copy.id, '');
  });

  test('mealEmoji', () {
    expect(mealEmoji('Petit-déjeuner'), '🍳');
    expect(mealEmoji('Déjeuner'), '🍗');
    expect(mealEmoji('Collation'), '🥤');
    expect(mealEmoji('Dîner'), '🐟');
    expect(mealEmoji('Brunch'), '🍽️');
  });
}
