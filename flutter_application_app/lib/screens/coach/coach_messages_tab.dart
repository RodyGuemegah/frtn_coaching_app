import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/chat_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';
import '../../widgets/cartes.dart';
import '../chat_screen.dart';

/// Onglet « Messages » du coach : une ligne par élève actif,
/// conversations récentes en premier, avec compteur de non-lus.
class CoachMessagesTab extends StatelessWidget {
  final AppUser coach;
  final List<AppUser> students;
  final Map<String, ChatThread> threads;
  final Object? error;
  final VoidCallback onRetry;

  const CoachMessagesTab({
    super.key,
    required this.coach,
    required this.students,
    required this.threads,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Élèves avec conversation (du plus récent au plus ancien), puis les autres par nom.
    final withThread = students.where((s) => threads[s.uid]?.lastAt != null).toList()
      ..sort((a, b) => threads[b.uid]!.lastAt!.compareTo(threads[a.uid]!.lastAt!));
    final without = students.where((s) => threads[s.uid]?.lastAt == null).toList();
    final unread = withThread.fold<int>(0, (n, s) => n + threads[s.uid]!.unreadForCoach);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        ScreenTitle(
          'Messages',
          subtitle: unread == 0 ? 'Tout est lu' : '$unread message${unread > 1 ? 's' : ''} non lu${unread > 1 ? 's' : ''}',
        ),
        const SizedBox(height: 16),
        if (error != null) ...[
          ErrorCard(message: friendlyErrorMessage(error!), onRetry: onRetry),
          const SizedBox(height: 12),
        ],
        if (students.isEmpty)
          const NoticeCard('Ajoute un élève pour pouvoir échanger avec lui.', icon: Icons.group_add_outlined)
        else ...[
          for (final s in withThread) _ThreadRow(coach: coach, student: s, thread: threads[s.uid]),
          if (without.isNotEmpty) ...[
            if (withThread.isNotEmpty) const SectionLabel('Démarrer une conversation'),
            for (final s in without) _ThreadRow(coach: coach, student: s, thread: null),
          ],
        ],
      ],
    );
  }
}

class _ThreadRow extends StatelessWidget {
  final AppUser coach;
  final AppUser student;
  final ChatThread? thread;
  const _ThreadRow({required this.coach, required this.student, required this.thread});

  @override
  Widget build(BuildContext context) {
    final t = thread;
    final unread = t?.unreadForCoach ?? 0;
    final preview = t == null || t.lastAt == null
        ? 'Aucun message'
        : '${t.lastSenderRole == 'coach' ? 'Toi : ' : ''}${t.lastText}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatScreen(student: student, coachUid: coach.uid, coachName: coach.nameOrEmail),
        )),
        decoration: unread > 0
            ? BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.7)),
              )
            : null,
        child: Row(
          children: [
            InitialsAvatar(student.initials),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.nameOrEmail, style: AppText.itemTitle),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      color: unread > 0 ? AppColors.text : AppColors.muted,
                      fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (t?.lastAt != null) Text(_when(t!.lastAt!), style: AppText.caption.copyWith(fontSize: 11)),
                if (unread > 0) ...[
                  const SizedBox(height: 4),
                  UnreadBadge(count: unread),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// « 18h42 » aujourd'hui, « Hier », sinon « 12/10 ».
  static String _when(DateTime d) {
    final now = DateTime.now();
    if (isSameDay(d, now)) return formatTime(d);
    if (isSameDay(d, now.subtract(const Duration(days: 1)))) return 'Hier';
    return formatDate(d);
  }
}

/// Pastille rouge du nombre de messages non lus.
class UnreadBadge extends StatelessWidget {
  final int count;
  const UnreadBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
