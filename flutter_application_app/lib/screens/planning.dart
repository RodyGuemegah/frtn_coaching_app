import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/cartes.dart';

class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      children: [
        const Text('Emploi du temps',
            style: TextStyle(color: AppColors.text, fontSize: 21, fontWeight: FontWeight.w800)),
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
