import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/cartes.dart';
import '../widgets/ressenti_sheet.dart';
import '../widgets/tags.dart';

/// Détail d'une séance. Côté élève : permet de la marquer comme faite avec un
/// ressenti. Côté coach (`readOnly`) : consultation uniquement.
class SessionDetailScreen extends StatefulWidget {
  final String uid;
  final SessionModel session;
  final bool readOnly;

  const SessionDetailScreen({super.key, required this.uid, required this.session, this.readOnly = false});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late final Stream<SessionModel?> _stream = SessionService().watchSession(widget.uid, widget.session.id);
  bool _saving = false;

  Future<void> _markDone(SessionModel session) async {
    final feedback = await showRessentiSheet(context);
    if (feedback == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await SessionService().markDone(widget.uid, session.id, feedback);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Séance enregistrée, bravo 💪')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.accent,
        title: const Text('Séance', style: TextStyle(color: AppColors.text)),
      ),
      body: StreamBuilder<SessionModel?>(
        stream: _stream,
        initialData: widget.session,
        builder: (context, snapshot) {
          final session = snapshot.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              if (snapshot.hasError) ...[
                ErrorCard(message: friendlyErrorMessage(snapshot.error!)),
                const SizedBox(height: 12),
              ],
              if (session == null)
                const AppCard(child: Text('Cette séance a été supprimée.', style: TextStyle(color: AppColors.muted)))
              else
                ..._buildSession(context, session),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildSession(BuildContext context, SessionModel s) {
    final coach = s.coachName?.trim().isNotEmpty == true ? s.coachName!.trim() : 'ton coach';
    final duration = s.durationMin != null ? ' · ~${s.durationMin} min' : '';
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: TagChip(sessionDateTag(s.date), style: s.isDone ? TagStyle.neutral : TagStyle.today),
      ),
      const SizedBox(height: 8),
      Text(s.title, style: const TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('Assignée par $coach$duration', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
      if (s.coachNote != null) ...[
        const SizedBox(height: 14),
        AppCard(
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
              children: [
                const TextSpan(text: '📝 '),
                const TextSpan(text: 'Consigne du coach : ', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                TextSpan(text: s.coachNote),
              ],
            ),
          ),
        ),
      ],
      const SectionLabel('Exercices'),
      if (s.exercises.isEmpty)
        const AppCard(child: Text('Aucun exercice renseigné.', style: TextStyle(color: AppColors.muted)))
      else
        for (int i = 0; i < s.exercises.length; i++)
          ExerciseRow(index: i + 1, name: s.exercises[i].name, detail: s.exercises[i].label),
      const SizedBox(height: 12),
      if (s.isDone) _DoneCard(session: s)
      else if (!widget.readOnly)
        PrimaryButton(label: '✓ Marquer la séance comme faite', loading: _saving, onPressed: () => _markDone(s)),
      if (!widget.readOnly) ...[
        const SizedBox(height: 10),
        GhostButton(
          label: '💬 Envoyer un message au coach',
          onPressed: () => ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Messagerie bientôt disponible'))),
        ),
      ],
    ];
  }
}

class _DoneCard extends StatelessWidget {
  final SessionModel session;
  const _DoneCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final fb = session.feedback;
    return AppCard(
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Séance faite', style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              if (fb != null)
                TagChip(
                  session.feedbackValidated ? 'Retour validé' : 'En attente du coach',
                  style: session.feedbackValidated ? TagStyle.active : TagStyle.neutral,
                ),
            ],
          ),
          if (fb != null) ...[
            const SizedBox(height: 10),
            Text('Ressenti : ${fb.ressenti.emoji} ${fb.ressenti.label}',
                style: const TextStyle(color: AppColors.text, fontSize: 13)),
            if (fb.comment != null) ...[
              const SizedBox(height: 4),
              Text('« ${fb.comment} »', style: const TextStyle(color: AppColors.muted, fontSize: 13, fontStyle: FontStyle.italic)),
            ],
          ],
          if (session.doneAt != null) ...[
            const SizedBox(height: 6),
            Text('Le ${formatDayLong(session.doneAt!)}', style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
          ],
        ],
      ),
    );
  }
}
