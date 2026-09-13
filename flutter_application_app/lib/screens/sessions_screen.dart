import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/cartes.dart';
import '../widgets/tags.dart';
import 'session_detail.dart';

/// Onglet « Mes séances » (élève) : à venir puis terminées.
class SessionsScreen extends StatefulWidget {
  final String uid;
  const SessionsScreen({super.key, required this.uid});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  late final Stream<List<SessionModel>> _stream = SessionService().watchSessions(widget.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SessionModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const <SessionModel>[];
        final upcoming = sessions.where((s) => !s.isDone).toList()..sort((a, b) => a.date.compareTo(b.date));
        final done = sessions.where((s) => s.isDone).toList()..sort((a, b) => b.date.compareTo(a.date));

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            const Text('Mes séances', style: TextStyle(color: AppColors.text, fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              sessions.isEmpty ? 'Ton programme apparaîtra ici' : '${upcoming.length} à venir · ${done.length} terminée${done.length > 1 ? 's' : ''}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (snapshot.hasError)
              ErrorCard(message: friendlyErrorMessage(snapshot.error!))
            else if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: CircularProgressIndicator()))
            else if (sessions.isEmpty)
              const AppCard(child: Text('Aucune séance pour le moment.', style: TextStyle(color: AppColors.muted)))
            else ...[
              if (upcoming.isNotEmpty) ...[
                const SectionLabel('À venir'),
                for (final s in upcoming) SessionRow(session: s, onTap: () => _open(context, s)),
              ],
              if (done.isNotEmpty) ...[
                const SectionLabel('Terminées'),
                for (final s in done) SessionRow(session: s, onTap: () => _open(context, s)),
              ],
            ],
          ],
        );
      },
    );
  }

  void _open(BuildContext context, SessionModel s) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SessionDetailScreen(uid: widget.uid, session: s)),
    );
  }
}

/// Ligne de séance réutilisable (élève et fiche élève côté coach).
class SessionRow extends StatelessWidget {
  final SessionModel session;
  final VoidCallback? onTap;

  const SessionRow({super.key, required this.session, this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final now = DateTime.now();
    final TagStyle style = s.isDone
        ? TagStyle.neutral
        : isSameDay(s.date, now)
            ? TagStyle.today
            : TagStyle.active;
    final details = <String>[
      '${s.exercises.length} exercice${s.exercises.length > 1 ? 's' : ''}',
      if (s.durationMin != null) '~${s.durationMin} min',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TagChip(sessionDateTag(s.date, now), style: style),
                  const SizedBox(height: 6),
                  Text(s.title, style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(details.join(' · '), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (s.isDone)
              Column(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.accent),
                  if (s.feedback != null) ...[
                    const SizedBox(height: 4),
                    Text(s.feedback!.ressenti.emoji, style: const TextStyle(fontSize: 16)),
                  ],
                ],
              )
            else
              const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
