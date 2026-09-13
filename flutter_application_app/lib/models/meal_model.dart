import 'firestore_helpers.dart';

class MealModel {
  final String id, title, time;
  final DateTime date;
  final int kcal, protein, carbs, fat;
  final bool eaten;

  const MealModel({
    required this.id,
    required this.title,
    required this.time,
    required this.date,
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
      kcal: parseInt(data['kcal']),
      protein: parseInt(data['protein']),
      carbs: parseInt(data['carbs']),
      fat: parseInt(data['fat']),
      eaten: data['eaten'] == true,
    );
  }
}
