import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/program.dart';
import '../../models/session_model.dart';
import '../../services/program_service.dart';
import '../../services/session_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/coach_stats.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';
import '../../utils/program_stats.dart';
import '../../widgets/cartes.dart';
import '../../widgets/current_user_scope.dart';
import '../../widgets/feedback.dart';
import '../../widgets/program_card.dart';
import '../../widgets/tags.dart';
import '../session_detail.dart';
import '../chat_screen.dart';
import '../measurements_screen.dart';
import '../planning.dart';
import '../sessions_screen.dart';
import 'coach_add_student.dart';
import 'coach_create_session.dart';
import 'coach_meal_plan.dart';
import 'program_editor.dart';
import 'program_report_screen.dart';

/// Fiche élève côté coach : stats, dernier retour, séances, actions rapides.
class CoachStudentDetailScreen extends StatefulWidget {
  final AppUser student;
  const CoachStudentDetailScreen({super.key, required this.student});

  @override
  State<CoachStudentDetailScreen> createState() =>
      _CoachStudentDetailScreenState();
}

class _CoachStudentDetailScreenState extends State<CoachStudentDetailScreen> {
  late final Stream<List<SessionModel>> _sessions = SessionService()
      .watchSessions(widget.student.uid);

  /// Profil écouté en direct : la fiche se met à jour après une modification.
  late final Stream<AppUser?> _profile = UserService().watchUser(
    widget.student.uid,
  );

  /// Dernière version connue de l'élève (celle reçue de la liste au départ).
  late AppUser _student = widget.student;
  bool _validating = false;

  void _editProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoachAddStudentScreen(initial: _student),
      ),
    );
  }

  /// Ouvre la conversation avec l'élève, éventuellement à propos d'une séance.
  void _openChat({SessionModel? session}) {
    final coach = CurrentUserScope.of(context);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        student: _student,
        coachUid: coach.uid,
        coachName: coach.nameOrEmail,
        sessionId: session?.id,
        sessionTitle: session?.title,
      ),
    ));
  }

  /// Retire l'élève (archivage) après confirmation, ou le réactive.
  Future<void> _setArchived(bool archived) async {
    final name = _student.shortName;
    if (archived) {
      final ok = await showConfirmDialog(
        context,
        title: 'Retirer $name ?',
        message:
            '$name disparaîtra de ton dashboard et n\'aura plus accès à l\'app. '
            'Son historique (séances, retours, repas) est conservé et tu pourras le réactiver à tout moment.',
        confirmLabel: 'Retirer',
      );
      if (!ok || !mounted) return;
    }
    try {
      await UserService().setArchived(_student.uid, archived);
      if (!mounted) return;
      showToast(
        context,
        archived
            ? '$name a été retiré — retrouve-le dans « Anciens élèves »'
            : '$name est de nouveau actif',
        type: archived ? ToastType.info : ToastType.success,
      );
    } catch (e) {
      if (mounted) {
        showToast(context, friendlyErrorMessage(e), type: ToastType.error);
      }
    }
  }

  Future<void> _validate(SessionModel session) async {
    if (_validating) return;
    setState(() => _validating = true);
    try {
      await SessionService().validateFeedback(widget.student.uid, session.id);
      if (!mounted) return;
      showToast(
        context,
        'Retour validé — ${_student.shortName} le verra dans son historique',
      );
    } catch (e) {
      if (!mounted) return;
      showToast(context, friendlyErrorMessage(e), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _profile,
      builder: (context, profileSnap) {
        if (profileSnap.data != null) _student = profileSnap.data!;
        return _buildPage(context);
      },
    );
  }

  Widget _buildPage(BuildContext context) {
    final student = _student;
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
        title: Text(AppText.upper(student.nameOrEmail)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) => switch (v) {
              'edit' => _editProfile(),
              'archive' => _setArchived(true),
              _ => _setArchived(false),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Modifier la fiche'),
                  ],
                ),
              ),
              if (student.archived)
                const PopupMenuItem(
                  value: 'restore',
                  child: Row(
                    children: [
                      Icon(Icons.unarchive_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Réactiver l\'élève'),
                    ],
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'archive',
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_remove_outlined,
                        size: 18,
                        color: AppColors.accent,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Retirer l\'élève',
                        style: TextStyle(color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<SessionModel>>(
        stream: _sessions,
        builder: (context, snapshot) {
          final sessions = snapshot.data ?? const <SessionModel>[];
          final stats = studentStats(sessions, DateTime.now());
          final last = stats.lastFeedbackSession;
          final upcoming = sessions.where((s) => !s.isDone).toList()
            ..sort((a, b) => a.date.compareTo(b.date));
          final done = sessions.where((s) => s.isDone).toList()
            ..sort((a, b) => b.date.compareTo(a.date));

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
                        Text(
                          AppText.upper(student.nameOrEmail),
                          style: AppText.heroTitle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (student.goal != null) student.goal!,
                            if (details.isNotEmpty) details.join(' · '),
                          ].join(' · '),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        if (student.email.isNotEmpty)
                          Text(
                            student.email,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (student.archived) ...[
                AppCard(
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.archive_outlined,
                            color: AppColors.muted,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${student.shortName} a été retiré${student.archivedAt != null ? ' le ${formatDate(student.archivedAt!)}' : ''}. '
                              'Son accès est suspendu, son historique reste consultable.',
                              style: AppText.caption.copyWith(
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GhostButton(
                        label: '↺ Réactiver ${student.shortName}',
                        onPressed: () => _setArchived(false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
                  StatTile(
                    value: stats.attendancePct == null
                        ? '—'
                        : '${stats.attendancePct}%',
                    label: 'Assiduité',
                  ),
                  StatTile(value: '${stats.done}', label: 'Séances faites'),
                ],
              ),
              const SectionLabel('Programme'),
              _ProgramSection(student: student),
              const SectionLabel('Suivi du poids'),
              WeightSummaryCard(student: student, coachMode: true),
              const SectionLabel("Dernier retour de l'élève"),
              if (last == null)
                const AppCard(
                  child: Text(
                    'Aucun retour pour le moment.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else
                _FeedbackCard(
                  session: last,
                  validating: _validating,
                  onValidate: last.feedbackValidated
                      ? null
                      : () => _validate(last),
                  onReply: () => _openChat(session: last),
                ),
              const SectionLabel('Séances'),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (sessions.isEmpty)
                const AppCard(
                  child: Text(
                    'Aucune séance assignée.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else ...[
                for (final s in upcoming)
                  SessionRow(session: s, onTap: () => _open(s)),
                for (final s in done)
                  SessionRow(session: s, onTap: () => _open(s)),
              ],
              if (!student.archived) ...[
                const SectionLabel('Actions rapides'),
                AppCard(
                  onTap: () => _openChat(),
                  child: _actionRow('💬', 'Messages', 'Écrire à ${student.shortName}'),
                ),
                const SizedBox(height: 10),
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CoachCreateSessionScreen(
                        students: [student],
                        preselectedStudentId: student.uid,
                      ),
                    ),
                  ),
                  child: _actionRow(
                    '💪',
                    'Assigner une séance',
                    'Nouvelle séance pour ${student.shortName}',
                  ),
                ),
                const SizedBox(height: 10),
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CoachMealPlanScreen(student: student),
                    ),
                  ),
                  child: _actionRow(
                    '🥗',
                    'Plan alimentaire',
                    'Repas jour par jour, macros, duplication',
                  ),
                ),
                const SizedBox(height: 10),
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CoachPlanningScreen(student: student)),
                  ),
                  child: _actionRow(
                    '📅',
                    "Ajuster l'emploi du temps",
                    'Séances, repas et créneaux de la semaine',
                  ),
                ),
                const SizedBox(height: 10),
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => MeasurementsScreen(student: student, coachMode: true)),
                  ),
                  child: _actionRow(
                    '📈',
                    'Voir les mesures & progrès',
                    'Pesées, tour de taille, masse grasse',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _open(SessionModel s) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionDetailScreen(
          uid: widget.student.uid,
          session: s,
          readOnly: true,
          student: _student, // active Modifier / Supprimer
        ),
      ),
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
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
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

  const _FeedbackCard({
    required this.session,
    required this.validating,
    required this.onValidate,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final fb = session.feedback!;
    return AppCard(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: session.feedbackValidated
              ? AppColors.border
              : AppColors.accent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(fb.ressenti.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fb.ressenti.label,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TagChip(
                session.feedbackValidated ? 'Validé' : 'À valider',
                style: session.feedbackValidated
                    ? TagStyle.active
                    : TagStyle.today,
              ),
            ],
          ),
          if (fb.comment != null) ...[
            const SizedBox(height: 8),
            Text(
              '« ${fb.comment} »',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '${session.title} · ${formatDate(session.date)}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: '✓ Valider',
                  loading: validating,
                  onPressed: onValidate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GhostButton(label: '💬 Répondre', onPressed: onReply),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/// Section « Programme » de la fiche élève : programme courant + actions
/// (créer, renouveler, modifier). Écoute les programmes de l'élève en direct.
class _ProgramSection extends StatefulWidget {
  final AppUser student;
  const _ProgramSection({required this.student});

  @override
  State<_ProgramSection> createState() => _ProgramSectionState();
}

class _ProgramSectionState extends State<_ProgramSection> {
  late final Stream<List<Program>> _stream = ProgramService().watchPrograms(widget.student.uid);

  void _openReport(Program program) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProgramReportScreen(student: widget.student, program: program),
    ));
  }

  void _open({Program? initial}) {
    showProgramEditor(
      context,
      student: widget.student,
      coach: CurrentUserScope.of(context),
      initial: initial,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Program>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return ErrorCard(message: friendlyErrorMessage(snap.error!));
        final programs = snap.data ?? const <Program>[];
        final now = DateTime.now();
        final current = currentProgram(programs, now);
        final renew = needsRenewal(programs, now);
        final archived = widget.student.archived;

        if (current == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NoticeCard('Aucun programme en cours. Crée-en un pour suivre la progression semaine par semaine.',
                  icon: Icons.flag_outlined),
              if (!archived) ...[
                const SizedBox(height: 10),
                PrimaryButton(label: '+ Créer un programme', onPressed: () => _open()),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProgramCard(
              program: current,
              showRenewal: true,
              needsRenewalFlag: renew,
              onTap: archived ? null : () => _open(initial: current),
            ),
            // Bilan disponible dès que le programme a commencé.
            if (programStatus(current, now) != ProgramStatus.upcoming) ...[
              const SizedBox(height: 10),
              GhostButton(
                label: programStatus(current, now) == ProgramStatus.finished
                    ? '📊 Voir le bilan du programme'
                    : '📊 Bilan intermédiaire',
                onPressed: () => _openReport(current),
              ),
            ],
            if (!archived) ...[
              const SizedBox(height: 10),
              if (renew)
                PrimaryButton(
                  label: '↻ Renouveler le programme',
                  onPressed: () => _open(initial: renewalOf(current, now)),
                )
              else
                GhostButton(label: '+ Nouveau programme', onPressed: () => _open()),
            ],
            // Historique : les autres programmes, du plus récent au plus ancien.
            if (programs.length > 1) ...[
              const SizedBox(height: 14),
              Text(AppText.upper('Historique des programmes'), style: AppText.section),
              const SizedBox(height: 8),
              for (final p in (programs.where((p) => p.id != current.id).toList()
                ..sort((a, b) => b.startDate.compareTo(a.startDate))))
                _PastProgramRow(
                  program: p,
                  onTap: programStatus(p, now) == ProgramStatus.upcoming ? () => _open(initial: p) : () => _openReport(p),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Ligne d'un programme passé (ou à venir) dans l'historique de la fiche élève.
class _PastProgramRow extends StatelessWidget {
  final Program program;
  final VoidCallback onTap;
  const _PastProgramRow({required this.program, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = program;
    final upcoming = programStatus(p, DateTime.now()) == ProgramStatus.upcoming;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(upcoming ? Icons.event_outlined : Icons.insights_rounded, size: 20, color: AppColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title, style: AppText.itemTitle.copyWith(fontSize: 14)),
                  Text('${formatDate(p.startDate)} → ${formatDate(p.lastDay)} · ${p.weeks} sem.', style: AppText.caption),
                ],
              ),
            ),
            Text(upcoming ? 'À venir' : 'Bilan', style: AppText.caption.copyWith(color: AppColors.accent2)),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
