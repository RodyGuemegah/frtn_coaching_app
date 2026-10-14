import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../theme/app_text.dart';
import '../widgets/current_user_scope.dart';
import 'planning_view.dart';

/// Onglet « Planning » de l'élève : son emploi du temps de la semaine.
class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlanningView(
      student: CurrentUserScope.of(context),
      header: const ScreenTitle('Emploi du temps', subtitle: 'Tes séances, repas et créneaux de la semaine'),
    );
  }
}

/// Emploi du temps d'un élève vu par son coach (route poussée depuis la fiche élève).
class CoachPlanningScreen extends StatelessWidget {
  final AppUser student;
  const CoachPlanningScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppText.upper('Emploi du temps'))),
      body: SafeArea(child: PlanningView(student: student, coachMode: true)),
    );
  }
}
