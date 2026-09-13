import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meal_model.dart';

class MealService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) => _db.collection('users/$uid/meals');

  /// Repas du jour d'un utilisateur, triés par date.
  Stream<List<MealModel>> watchTodayMeals(String uid) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    return _col(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs.map((d) => MealModel.fromDoc(d.id, d.data())).toList());
  }

  Future<void> toggleEaten(String uid, String mealId, bool eaten) =>
      _col(uid).doc(mealId).update({'eaten': eaten});
}
