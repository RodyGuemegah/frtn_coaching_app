import 'package:flutter/material.dart';
import '../models/meal_model.dart';
import '../services/meal_service.dart';
import '../theme/app_colors.dart';
import '../utils/errors.dart';
import '../widgets/cartes.dart';

class NutritionScreen extends StatefulWidget {
  final String uid;
  const NutritionScreen({super.key, required this.uid});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  late final Stream<List<MealModel>> _stream = MealService().watchTodayMeals(widget.uid);

  Future<void> _toggle(MealModel m) async {
    try {
      await MealService().toggleEaten(widget.uid, m.id, !m.eaten);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MealModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        final meals = snapshot.data ?? const <MealModel>[];
        final totalKcal = meals.fold<int>(0, (sum, m) => sum + m.kcal);
        final eatenKcal = meals.where((m) => m.eaten).fold<int>(0, (sum, m) => sum + m.kcal);
        final totalProt = meals.fold<int>(0, (sum, m) => sum + m.protein);

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            const Text('Programme alimentaire',
                style: TextStyle(color: AppColors.text, fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              meals.isEmpty ? 'Tes repas du jour apparaîtront ici' : 'Objectif : $totalKcal kcal · $totalProt g protéines',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (snapshot.hasError)
              ErrorCard(message: friendlyErrorMessage(snapshot.error!))
            else if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: CircularProgressIndicator()))
            else ...[
              _SummaryCard(eatenKcal: eatenKcal, totalKcal: totalKcal),
              const SectionLabel('Repas du jour'),
              if (meals.isEmpty)
                const AppCard(child: Text("Aucun repas programmé pour aujourd'hui.", style: TextStyle(color: AppColors.muted)))
              else
                for (final m in meals) _MealRow(meal: m, onTap: () => _toggle(m)),
            ],
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int eatenKcal, totalKcal;
  const _SummaryCard({required this.eatenKcal, required this.totalKcal});

  @override
  Widget build(BuildContext context) {
    final ratio = totalKcal == 0 ? 0.0 : (eatenKcal / totalKcal).clamp(0.0, 1.0);
    return AppCard(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Aujourd'hui", style: TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 2),
                Text('$eatenKcal / $totalKcal kcal',
                    style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: ratio,
                  strokeWidth: 6,
                  backgroundColor: AppColors.card2,
                  color: AppColors.accent,
                ),
                Text('${(ratio * 100).round()}%',
                    style: const TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  final MealModel meal;
  final VoidCallback onTap;
  const _MealRow({required this.meal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = meal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.time.isEmpty ? m.title : '${m.title} · ${m.time}',
                      style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${m.kcal} kcal · ${m.protein} g prot. · ${m.carbs} g gluc. · ${m.fat} g lip.',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              m.eaten ? Icons.check_circle : Icons.radio_button_unchecked,
              color: m.eaten ? AppColors.accent : AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}
