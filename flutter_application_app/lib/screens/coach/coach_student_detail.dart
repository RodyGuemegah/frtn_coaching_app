import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/session_model.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/coach_stats.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';
import '../../widgets/cartes.dart';
import '../../widgets/tags.dart';
import '../session_detail.dart';
import '../sessions_screen.dart';
import 'coach_create_session.dart';

/// Fiche élève côté coach : stats, dernier retour, séances, actions rapides.
class CoachStudentDetailScreen extends StatefulWidget {
  final AppUser student;
  const CoachStudentDetailScreen({super.key, required this.student});

  @override
  State<CoachStudentDetailScreen> createState() => _CoachStudentDetailScreenState();
}

class _CoachStudentDetailScreenState extends State<CoachStudentDetailScreen> {
  late final Stream<List<SessionModel>> _sessions = SessionService().watchSessions(widget.student.uid);
  bool _validating = false;

  Future<void> _validate(SessionModel session) async {
    if (_validating) return;
    setState(() => _validating = true);
    try {
      await SessionService().validateFeedback(widget.student.uid, session.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retour validé ✓')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final details = <String>[
      if (student.age != null) '${student.age} ans',
      if (student.heightCm != null) '${student.heightCm} cm',
      if (student.weightKg != null) '${student.weightKg} kg',
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.accent,
        title: Text(student.nameOrEmail, style: const TextStyle(color: AppColors.text)),
      ),
      body: StreamBuilder<List<SessionModel>>(
        stream: _sessions,
        builder: (context, snapshot) {
          final sessions = snapshot.data ?? const <SessionModel>[];
          final stats = studentStats(sessions, DateTime.now());
          final last = stats.lastFeedbackSession;
          final upcoming = sessions.where((s) => !s.isDone).toList()..sort((a, b) => a.date.compareTo(b.date));
          final done = sessions.where((s) => s.isDone).toList()..sort((a, b) => b.date.compareTo(a.date));

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              Row(
                children: [
                  InitialsAvatar(student.initials, radius: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.nameOrEmail, style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          [if (student.goal != null) student.goal!, if (details.isNotEmpty) details.join(' · ')].join(' · '),
                          style: const TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                        if (student.email.isNotEmpty)
                          Text(student.email, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (snapshot.hasError) ...[
                ErrorCard(message: friendlyErrorMessage(snapshot.error!)),
                const SizedBox(height: 12),
              ],
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.8,
                children: [
                  StatTile(value: stats.attendancePct == null ? '—' : '${stats.attendancePct}%', label: 'Assiduité'),
                  StatTile(value: '${stats.done}', label: 'Séances faites'),
                ],
              ),
              const SectionLabel("Dernier retour de l'élève"),
              if (last == null)
                const AppCard(child: Text('Aucun retour pour le moment.', style: TextStyle(color: AppColors.muted)))
              else
                _FeedbackCard(
                  session: last,
                  validating: _validating,
                  onValidate: last.feedbackValidated ? null : () => _validate(last),
                  onReply: () => _snack('Messagerie bientôt disponible'),
                ),
              const SectionLabel('Séances'),
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
              else if (sessions.isEmpty)
                const AppCard(child: Text('Aucune séance assignée.', style: TextStyle(color: AppColors.muted)))
              else ...[
                for (final s in upcoming) SessionRow(session: s, onTap: () => _open(s)),
                for (final s in done) SessionRow(session: s, onTap: () => _open(s)),
              ],
              const SectionLabel('Actions rapides'),
              AppCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CoachCreateSessionScreen(students: [student], preselectedStudentId: student.uid),
                  ),
                ),
                child: _actionRow('💪', 'Assigner une séance', 'Nouvelle séance pour ${student.shortName}'),
              ),
              const SizedBox(height: 10),
              AppCard(
                onTap: () => _snack('Plan alimentaire — bientôt disponible'),
                child: _actionRow('🥗', 'Modifier le plan alimentaire', 'Bientôt disponible'),
              ),
              const SizedBox(height: 10),
              AppCard(
                onTap: () => _snack("Emploi du temps — bientôt disponible"),
                child: _actionRow('📅', "Ajuster l'emploi du temps", 'Bientôt disponible'),
              ),
              const SizedBox(height: 10),
              AppCard(
                onTap: () => _snack('Mesures & progrès — bientôt disponible'),
                child: _actionRow('📈', 'Voir les mesures & progrès', 'Bientôt disponible'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _open(SessionModel s) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SessionDetailScreen(uid: widget.student.uid, session: s, readOnly: true)),
    );
  }

  Widget _actionRow(String emoji, String title, String subtitle) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: AppColors.muted),
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final SessionModel session;
  final bool validating;
  final VoidCallback? onValidate;
  final VoidCallback onReply;

  const _FeedbackCard({required this.session, required this.validating, required this.onValidate, required this.onReply});

  @override
  Widget build(BuildContext context) {
    final fb = session.feedback!;
    return AppCard(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: session.feedbackValidated ? AppColors.border : AppColors.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(fb.ressenti.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(fb.ressenti.label, style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              TagChip(
                session.feedbackValidated ? 'Validé' : 'À valider',
                style: session.feedbackValidated ? TagStyle.active : TagStyle.today,
              ),
            ],
          ),
          if (fb.comment != null) ...[
            const SizedBox(height: 8),
            Text('« ${fb.comment} »', style: const TextStyle(color: AppColors.text, fontSize: 13, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 6),
          Text('${session.title} · ${formatDate(session.date)}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: PrimaryButton(label: '✓ Valider', loading: validating, onPressed: onValidate)),
              const SizedBox(width: 8),
              Expanded(child: GhostButton(label: '💬 Répondre', onPressed: onReply)),
            ],
          ),
        ],
      ),
    );
  }
}
