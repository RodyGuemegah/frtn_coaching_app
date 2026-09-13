import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/meal_model.dart';
import '../models/session_model.dart';
import '../services/meal_service.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../utils/session_stats.dart';
import '../widgets/cartes.dart';
import '../widgets/current_user_scope.dart';
import '../widgets/tags.dart';
import 'nutrition.dart';
import 'planning.dart';
import 'profil.dart';
import 'session_detail.dart';
import 'sessions_screen.dart';

/// Coquille de l'app élève : contenu de l'onglet + barre de navigation basse.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  void _openTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final user = CurrentUserScope.of(context);
    final tabs = [
      _HomeTab(user: user, onOpenTab: _openTab),
      SessionsScreen(uid: user.uid),
      NutritionScreen(uid: user.uid),
      const PlanningScreen(),
      const ProfilScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: tabs)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _openTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Séances'),
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: 'Nutrition'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'Planning'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  final AppUser user;
  final void Function(int tab) onOpenTab;
  const _HomeTab({required this.user, required this.onOpenTab});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late final Stream<List<SessionModel>> _sessions = SessionService().watchSessions(widget.user.uid);
  late final Stream<List<MealModel>> _meals = MealService().watchTodayMeals(widget.user.uid);

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return StreamBuilder<List<SessionModel>>(
      stream: _sessions,
      builder: (context, snapshot) {
        final now = DateTime.now();
        final sessions = snapshot.data ?? const <SessionModel>[];
        final next = nextSession(sessions, now);
        final week = weekCount(sessions, now);
        final attendance = monthAttendancePct(sessions, now);

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Salut ${user.shortName} 👋',
                          style: const TextStyle(color: AppColors.text, fontSize: 21, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(todayLabel(now), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
                GestureDetector(onTap: () => widget.onOpenTab(4), child: InitialsAvatar(user.initials)),
              ],
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError)
              ErrorCard(message: friendlyErrorMessage(snapshot.error!))
            else if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: CircularProgressIndicator()))
            else if (next == null)
              const AppCard(child: Text('Aucune séance à venir pour le moment.', style: TextStyle(color: AppColors.muted)))
            else
              _NextSessionCard(session: next, onOpen: () => _openSession(next)),
            const SizedBox(height: 14),
            StreamBuilder<List<MealModel>>(
              stream: _meals,
              builder: (context, mealSnap) {
                final meals = mealSnap.data ?? const <MealModel>[];
                final kcalTarget = meals.fold<int>(0, (sum, m) => sum + m.kcal);
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    StatTile(value: '${week.done}/${week.total}', label: 'Séances cette semaine'),
                    StatTile(value: attendance == null ? '—' : '$attendance%', label: 'Assiduité du mois'),
                    StatTile(value: kcalTarget > 0 ? '$kcalTarget' : '—', label: 'Objectif kcal / jour'),
                    StatTile(value: '${totalDone(sessions)}', label: 'Séances complétées'),
                  ],
                );
              },
            ),
            const SectionLabel('Prochains repas'),
            StreamBuilder<List<MealModel>>(
              stream: _meals,
              builder: (context, mealSnap) {
                if (mealSnap.hasError) return ErrorCard(message: friendlyErrorMessage(mealSnap.error!));
                final meals = mealSnap.data ?? const <MealModel>[];
                final upcoming = meals.where((m) => !m.eaten).toList();
                if (upcoming.isEmpty) {
                  return AppCard(
                    onTap: () => widget.onOpenTab(2),
                    child: Text(
                      meals.isEmpty ? "Aucun repas prévu aujourd'hui." : 'Tous les repas du jour sont cochés ✓',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final m in upcoming.take(2))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          onTap: () => widget.onOpenTab(2),
                          child: Row(
                            children: [
                              const Text('🍽️', style: TextStyle(fontSize: 22)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.time.isEmpty ? m.title : '${m.title} · ${m.time}',
                                        style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text('${m.kcal} kcal · ${m.protein} g protéines',
                                        style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.muted),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _openSession(SessionModel s) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SessionDetailScreen(uid: widget.user.uid, session: s)),
    );
  }
}

class _NextSessionCard extends StatelessWidget {
  final SessionModel session;
  final VoidCallback onOpen;
  const _NextSessionCard({required this.session, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final details = <String>[
      '${s.exercises.length} exercice${s.exercises.length > 1 ? 's' : ''}',
      if (s.durationMin != null) '~${s.durationMin} min',
    ];
    return AppCard(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A070C), AppColors.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(alignment: Alignment.centerLeft, child: TagChip(sessionDateTag(s.date), style: TagStyle.today)),
          const SizedBox(height: 8),
          Text(s.title, style: const TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(details.join(' · '), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 14),
          PrimaryButton(label: 'Voir la séance →', onPressed: onOpen),
        ],
      ),
    );
  }
}
