import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meal_model.dart';

class MealService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) => _db.collection('users/$uid/meals');

  static List<MealModel> _fromSnap(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => MealModel.fromDoc(d.id, d.data())).toList();

  /// Repas entre [start] (inclus) et [end] (exclu), triés par date.
  Stream<List<MealModel>> watchMealsBetween(String uid, DateTime start, DateTime end) => _col(uid)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('date', isLessThan: Timestamp.fromDate(end))
      .orderBy('date')
      .snapshots()
      .map(_fromSnap);

  /// Repas d'une journée (00:00 → 24:00), triés par heure.
  Stream<List<MealModel>> watchMealsForDay(String uid, DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return watchMealsBetween(uid, start, start.add(const Duration(days: 1)));
  }

  /// Repas du jour d'un utilisateur, triés par heure.
  Stream<List<MealModel>> watchTodayMeals(String uid) => watchMealsForDay(uid, DateTime.now());

  Future<void> toggleEaten(String uid, String mealId, bool eaten) =>
      _col(uid).doc(mealId).update({'eaten': eaten});

  // --- Coach ---

  Future<void> createMeal(String uid, MealModel meal) =>
      _col(uid).add({...meal.toMap(), 'createdAt': FieldValue.serverTimestamp()});

  /// Met à jour le contenu d'un repas sans toucher à son état « mangé ».
  Future<void> updateMeal(String uid, MealModel meal) {
    final data = meal.toMap()..remove('eaten');
    if (meal.description == null || meal.description!.isEmpty) data['description'] = FieldValue.delete();
    return _col(uid).doc(meal.id).update(data);
  }

  Future<void> deleteMeal(String uid, String mealId) => _col(uid).doc(mealId).delete();

  /// Copie les repas [meals] sur chacun des jours [targetDays].
  /// Si [replace] est vrai, les repas déjà présents sur ces jours sont supprimés avant.
  Future<int> copyMealsToDays(String uid, List<MealModel> meals, List<DateTime> targetDays, {bool replace = false}) async {
    var batch = _db.batch();
    var ops = 0;
    var created = 0;

    Future<void> commitIfFull() async {
      if (ops >= 450) {
        await batch.commit();
        batch = _db.batch();
        ops = 0;
      }
    }

    for (final day in targetDays) {
      if (replace) {
        final start = DateTime(day.year, day.month, day.day);
        final existing = await _col(uid)
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('date', isLessThan: Timestamp.fromDate(start.add(const Duration(days: 1))))
            .get();
        for (final d in existing.docs) {
          batch.delete(d.reference);
          ops++;
          await commitIfFull();
        }
      }
      for (final m in meals) {
        batch.set(_col(uid).doc(), {...m.copyToDay(day).toMap(), 'createdAt': FieldValue.serverTimestamp()});
        ops++;
        created++;
        await commitIfFull();
      }
    }
    if (ops > 0) await batch.commit();
    return created;
  }
}
