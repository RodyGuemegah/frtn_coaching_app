import 'package:flutter/material.dart';
import '../models/meal_model.dart';
import '../theme/app_colors.dart';

/// Rangée de pastilles macros (« 720 kcal · 48 g Prot. · … ») façon maquette.
class MacroChips extends StatelessWidget {
  final int kcal, protein, carbs, fat;
  final bool showKcal;

  const MacroChips({super.key, required this.kcal, required this.protein, required this.carbs, required this.fat, this.showKcal = true});

  factory MacroChips.ofMeal(MealModel m) => MacroChips(kcal: m.kcal, protein: m.protein, carbs: m.carbs, fat: m.fat);

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      if (showKcal) ('$kcal', 'kcal'),
      ('$protein g', 'Prot.'),
      ('$carbs g', 'Gluc.'),
      ('$fat g', 'Lip.'),
    ];
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Text(items[i].$1, style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(items[i].$2, style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
                ],
              ),
            ),
          ),
          if (i < items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
