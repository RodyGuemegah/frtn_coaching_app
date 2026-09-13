import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/session_model.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/coach_stats.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';
import '../../widgets/cartes.dart';
import '../../widgets/current_user_scope.dart';
import '../../widgets/tags.dart';
import 'coach_add_student.dart';
import 'coach_create_session.dart';
import 'coach_student_detail.dart';

/// Données partagées par les onglets de l'espace coach.
class CoachData {
  final AppUser me;
  final List<AppUser> students;
  final List<SessionModel> sessions;
  final CoachStats stats;
  final bool loading;
  final Object? studentsError;
  final Object? sessionsError;

  const CoachData({
    required this.me,
    required this.students,
    required this.sessions,
    required this.stats,
    required this.loading,
    this.studentsError,
    this.sessionsError,
  });
}

/// Coquille de l'espace coach : dashboard / élèves / créer une séance.
/// Les deux streams (élèves, séances assignées) vivent ici et sont partagés.
class CoachShell extends StatefulWidget {
  const CoachShell({super.key});

  @override
  State<CoachShell> createState() => _CoachShellState();
}

class _CoachShellState extends State<CoachShell> {
  int _index = 0;
  StreamSubscription<List<AppUser>>? _studentsSub;
  StreamSubscription<List<SessionModel>>? _sessionsSub;
  List<AppUser> _students = const [];
  List<SessionModel> _sessions = const [];
  bool _studentsLoaded = false;
  bool _sessionsLoaded = false;
  Object? _studentsError;
  Object? _sessionsError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_studentsSub == null) _start(CurrentUserScope.of(context).uid);
  }

  void _start(String uid) {
    _studentsSub = UserService().watchMyStudents(uid).listen(
      (list) => setState(() {
        _students = list;
        _studentsLoaded = true;
        _studentsError = null;
      }),
      onError: (Object e) => setState(() {
        _studentsError = e;
        _studentsLoaded = true;
      }),
    );
    final since = DateTime.now().subtract(const Duration(days: 60));
    _sessionsSub = SessionService().watchCoachSessions(uid, since: since).listen(
      (list) => setState(() {
        _sessions = list;
        _sessionsLoaded = true;
        _sessionsError = null;
      }),
      onError: (Object e) => setState(() {
        _sessionsError = e;
        _sessionsLoaded = true;
      }),
    );
  }

  void _retry() {
    _studentsSub?.cancel();
    _sessionsSub?.cancel();
    setState(() {
      _studentsLoaded = false;
      _sessionsLoaded = false;
      _studentsError = null;
      _sessionsError = null;
    });
    _start(CurrentUserScope.of(context).uid);
  }

  void _openTab(int i) => setState(() => _index = i);

  @override
  void dispose() {
    _studentsSub?.cancel();
    _sessionsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = CurrentUserScope.of(context);
    final data = CoachData(
      me: me,
      students: _students,
      sessions: _sessions,
      stats: coachStats(_students, _sessions, DateTime.now()),
      loading: !(_studentsLoaded && _sessionsLoaded),
      studentsError: _studentsError,
      sessionsError: _sessionsError,
    );
    final tabs = [
      _CoachDashboardTab(data: data, onOpenTab: _openTab, onRetry: _retry),
      _CoachStudentsTab(data: data, onRetry: _retry),
      CoachCreateSessionForm(students: _students),
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: IndexedStack(index: _index, children: tabs)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _openTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Élèves'),
          NavigationDestination(icon: Icon(Icons.edit_outlined), selectedIcon: Icon(Icons.edit), label: 'Créer'),
        ],
      ),
    );
  }
}

class _CoachDashboardTab extends StatelessWidget {
  final CoachData data;
  final void Function(int) onOpenTab;
  final VoidCallback onRetry;
  const _CoachDashboardTab({required this.data, required this.onOpenTab, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final stats = data.stats;
    final n = data.students.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Espace coach', style: TextStyle(color: AppColors.text, fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${todayLabel()} · $n élève${n > 1 ? 's' : ''} actif${n > 1 ? 's' : ''}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              color: AppColors.panel,
              onSelected: (v) {
                if (v == 'logout') AuthService().signOut();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'logout', child: Text('Se déconnecter')),
              ],
              child: InitialsAvatar(data.me.initials, style: AvatarStyle.bordered),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Une carte par message distinct (les deux streams échouent souvent pour la même raison).
        for (final message in {
          if (data.studentsError != null) friendlyErrorMessage(data.studentsError!),
          if (data.sessionsError != null) friendlyErrorMessage(data.sessionsError!),
        }) ...[
          ErrorCard(message: message, onRetry: onRetry),
          const SizedBox(height: 12),
        ],
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            StatTile(value: '${stats.sessionsToday}', label: "Séances aujourd'hui"),
            StatTile(value: '${stats.pendingFeedback}', label: 'Retours à valider'),
            StatTile(value: stats.attendanceAvgPct == null ? '—' : '${stats.attendanceAvgPct}%', label: 'Assiduité moyenne'),
            // Aucun modèle de "programme" n'existe encore : placeholder assumé.
            const StatTile(value: '—', label: 'Programmes à renouveler'),
          ],
        ),
        if (stats.alerts.isNotEmpty) ...[
          const SectionLabel('⚠️ À traiter'),
          for (final a in stats.alerts) _AlertRow(alert: a),
        ],
        const SectionLabel('Mes élèves'),
        if (data.loading && data.students.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
        else if (data.students.isEmpty)
          const AppCard(child: Text('Aucun élève pour le moment. Ajoute ton premier élève !', style: TextStyle(color: AppColors.muted)))
        else
          for (final s in data.students) StudentRow(student: s, stats: stats.of(s.uid)),
        const SizedBox(height: 8),
        if (data.students.isEmpty)
          PrimaryButton(label: '+ Ajouter un élève', onPressed: () => _addStudent(context))
        else
          PrimaryButton(label: '+ Créer une séance', onPressed: () => onOpenTab(2)),
      ],
    );
  }

  void _addStudent(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoachAddStudentScreen()));
  }
}

class _CoachStudentsTab extends StatelessWidget {
  final CoachData data;
  final VoidCallback onRetry;
  const _CoachStudentsTab({required this.data, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final n = data.students.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        const Text('Mes élèves', style: TextStyle(color: AppColors.text, fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(n == 0 ? 'Aucun élève rattaché' : '$n élève${n > 1 ? 's' : ''}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 16),
        PrimaryButton(
          label: '+ Ajouter un élève',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoachAddStudentScreen())),
        ),
        const SizedBox(height: 16),
        if (data.studentsError != null)
          ErrorCard(message: friendlyErrorMessage(data.studentsError!), onRetry: onRetry)
        else if (data.loading && data.students.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
        else if (data.students.isEmpty)
          const AppCard(child: Text("Crée un compte élève : il recevra un email pour choisir son mot de passe.", style: TextStyle(color: AppColors.muted)))
        else
          for (final s in data.students) StudentRow(student: s, stats: data.stats.of(s.uid)),
      ],
    );
  }
}

class _AlertRow extends StatelessWidget {
  final StudentAlert alert;
  const _AlertRow({required this.alert});

  @override
  Widget build(BuildContext context) {
    final s = alert.student;
    final st = alert.stats;
    final String subtitle;
    final String tag;
    switch (alert.reason) {
      case AlertReason.pendingFeedback:
        final title = st.lastFeedbackSession?.title;
        subtitle = '${st.pendingFeedback} retour${st.pendingFeedback > 1 ? 's' : ''} à valider${title != null ? ' · $title' : ''}';
        tag = 'Valider';
        break;
      case AlertReason.lowAttendance:
        subtitle = 'Assiduité ${st.attendancePct}% sur ${st.pastTotal} séances';
        tag = 'Relancer';
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CoachStudentDetailScreen(student: s)),
        ),
        child: Row(
          children: [
            InitialsAvatar(s.initials, style: AvatarStyle.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.nameOrEmail, style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            TagChip(tag, style: TagStyle.today),
          ],
        ),
      ),
    );
  }
}

/// Ligne élève (dashboard + onglet élèves).
class StudentRow extends StatelessWidget {
  final AppUser student;
  final StudentStats stats;
  const StudentRow({super.key, required this.student, required this.stats});

  @override
  Widget build(BuildContext context) {
    final TagStyle tagStyle;
    final String tagLabel;
    if (stats.hasPendingFeedback) {
      tagStyle = TagStyle.today;
      tagLabel = '⚠ Retour';
    } else if (stats.lowAttendance) {
      tagStyle = TagStyle.today;
      tagLabel = '⚠';
    } else if (stats.pastTotal == 0 && stats.next == null) {
      tagStyle = TagStyle.neutral;
      tagLabel = 'Nouveau';
    } else {
      tagStyle = TagStyle.active;
      tagLabel = 'OK';
    }
    final parts = <String>[
      if (student.goal != null) student.goal!,
      if (stats.attendancePct != null) 'Assiduité ${stats.attendancePct}%'
      else if (stats.next != null) 'Prochaine : ${sessionDateTag(stats.next!.date)}'
      else 'Aucune séance',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CoachStudentDetailScreen(student: student)),
        ),
        child: Row(
          children: [
            InitialsAvatar(student.initials),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.nameOrEmail, style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(parts.join(' · '), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            TagChip(tagLabel, style: tagStyle),
          ],
        ),
      ),
    );
  }
}
