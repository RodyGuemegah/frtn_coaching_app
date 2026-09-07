import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../widgets/cartes.dart';
import '../widgets/tags.dart';
import 'nutrition.dart';
import 'planning.dart';
import 'profil.dart';
import 'sessions_screen.dart';

/// Coquille de l'app connectée : contenu de l'onglet + barre de navigation basse.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  void _goToProfil() => setState(() => _index = 4);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _HomeTab(onAvatarTap: _goToProfil),
      const SessionsScreen(),
      const NutritionScreen(),
      const PlanningScreen(),
      const ProfilScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: tabs)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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

class _HomeTab extends StatelessWidget {
  final VoidCallback onAvatarTap;
  const _HomeTab({required this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim().split(' ').first
        : (user?.email?.split('@').first ?? 'Champion');
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return StreamBuilder<List<SessionModel>>(
      stream: SessionService().watchSessions(),
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const <SessionModel>[];
        final nextSession = _nextSession(sessions);
        final weekCount = _thisWeekCount(sessions);

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
                      Text('Salut $displayName 👋',
                          style: const TextStyle(color: AppColors.text, fontSize: 21, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(_todayLabel(), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onAvatarTap,
                  child: CircleAvatar(
                    radius: 21,
                    backgroundColor: AppColors.accentDark,
                    child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (nextSession == null)
              const AppCard(
                child: Text('Aucune séance à venir pour le moment.', style: TextStyle(color: AppColors.muted)),
              )
            else
              _NextSessionCard(session: nextSession),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                StatTile(value: weekCount, label: 'Séances cette semaine'),
                const StatTile(value: '—', label: 'Assiduité du mois'),
                const StatTile(value: '—', label: 'Objectif kcal / jour'),
                const StatTile(value: '—', label: 'Depuis le début'),
              ],
            ),
            const SectionLabel('Prochains repas'),
            AppCard(
              onTap: () {},
              child: const Text(
                'Le programme alimentaire arrive bientôt 🥗',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ],
        );
      },
    );
  }

  String _todayLabel() {
    const jours = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
    const mois = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    final now = DateTime.now();
    return '${jours[now.weekday - 1]} ${now.day} ${mois[now.month - 1]}';
  }

  SessionModel? _nextSession(List<SessionModel> sessions) {
    final upcoming = sessions.where((s) => s.status != 'done').toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  String _thisWeekCount(List<SessionModel> sessions) {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    final thisWeek = sessions.where((s) => s.date.isAfter(startOfWeek) && s.date.isBefore(endOfWeek));
    final done = thisWeek.where((s) => s.status == 'done').length;
    return '$done/${thisWeek.length}';
  }
}

class _NextSessionCard extends StatelessWidget {
  final SessionModel session;
  const _NextSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(session.date);
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
          TagChip(
            isToday ? "Aujourd'hui · ${_time(session.date)}" : '${_dateLabel(session.date)} · ${_time(session.date)}',
            style: TagStyle.today,
          ),
          const SizedBox(height: 8),
          Text(session.title, style: const TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('${session.exercises.length} exercices', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 14),
          PrimaryButton(label: 'Voir la séance →', onPressed: () {}),
        ],
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';

  String _dateLabel(DateTime d) => '${d.day}/${d.month}';
}
