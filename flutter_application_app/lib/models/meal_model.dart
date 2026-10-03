import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_helpers.dart';

/// Libellés proposés au coach lors de la création d'un repas.
const mealTitleSuggestions = ['Petit-déjeuner', 'Déjeuner', 'Collation', 'Dîner', 'Pré-training', 'Post-training'];

/// Emoji indicatif selon le libellé du repas.
String mealEmoji(String title) {
  final t = title.toLowerCase();
  if (t.contains('petit')) return '🍳';
  if (t.contains('déj') || t.contains('dej')) return '🍗';
  if (t.contains('collation') || t.contains('training')) return '🥤';
  if (t.contains('dîner') || t.contains('diner')) return '🐟';
  return '🍽️';
}

class MealModel {
  final String id, title, time;
  final DateTime date;
  final String? description;
  final int kcal, protein, carbs, fat;
  final bool eaten;

  const MealModel({
    required this.id,
    required this.title,
    required this.time,
    required this.date,
    this.description,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.eaten,
  });

  factory MealModel.fromDoc(String id, Map<String, dynamic> data) {
    return MealModel(
      id: id,
      title: parseString(data['title']),
      time: parseString(data['time']),
      date: parseDate(data['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      description: parseStringOrNull(data['description']),
      kcal: parseInt(data['kcal']),
      protein: parseInt(data['protein']),
      carbs: parseInt(data['carbs']),
      fat: parseInt(data['fat']),
      eaten: data['eaten'] == true,
    );
  }

  /// Champs persistés (sans `createdAt`, posé par le service).
  Map<String, dynamic> toMap() => {
    'title': title,
    'time': time,
    'date': Timestamp.fromDate(date),
    if (description != null && description!.isNotEmpty) 'description': description,
    'kcal': kcal,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'eaten': eaten,
  };

  /// Copie du repas à une autre date (même heure), non cochée.
  MealModel copyToDay(DateTime day) => MealModel(
    id: '',
    title: title,
    time: time,
    date: DateTime(day.year, day.month, day.day, date.hour, date.minute),
    description: description,
    kcal: kcal,
    protein: protein,
    carbs: carbs,
    fat: fat,
    eaten: false,
  );
}

/// Totaux nutritionnels d'une liste de repas.
({int kcal, int protein, int carbs, int fat}) mealTotals(Iterable<MealModel> meals) {
  var k = 0, p = 0, c = 0, f = 0;
  for (final m in meals) {
    k += m.kcal;
    p += m.protein;
    c += m.carbs;
    f += m.fat;
  }
  return (kcal: k, protein: p, carbs: c, fat: f);
}

/// Estimation kcal à partir des macros (4 / 4 / 9).
int kcalFromMacros(int protein, int carbs, int fat) => protein * 4 + carbs * 4 + fat * 9;
