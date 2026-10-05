import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/cartes.dart';
import '../theme/app_text.dart';

class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      children: [
        const ScreenTitle('Emploi du temps'),
        const SizedBox(height: 16),
        const AppCard(
          child: Text(
            'Ton emploi du temps de la semaine arrivera ici.',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
