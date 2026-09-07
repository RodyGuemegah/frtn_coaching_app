import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/cartes.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      children: [
        const Text('Programme alimentaire',
            style: TextStyle(color: AppColors.text, fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        const AppCard(
          child: Text(
            'Ton coach n\'a pas encore configuré de programme alimentaire.\nReviens bientôt 🥗',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
