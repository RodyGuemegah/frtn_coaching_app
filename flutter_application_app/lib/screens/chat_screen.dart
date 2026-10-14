import 'dart:async';

import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/cartes.dart';
import '../widgets/current_user_scope.dart';
import '../widgets/feedback.dart';

/// Conversation coach ↔ élève (même écran des deux côtés).
///
/// [student] est l'élève propriétaire de la conversation ; [coachUid] / [coachName]
/// désignent son coach. Si [sessionId] est fourni, le premier message envoyé
/// fera référence à cette séance (ex : réponse à un ressenti).
class ChatScreen extends StatefulWidget {
  final AppUser student;
  final String coachUid;
  final String? coachName;
  final String? sessionId;
  final String? sessionTitle;

  const ChatScreen({
    super.key,
    required this.student,
    required this.coachUid,
    this.coachName,
    this.sessionId,
    this.sessionTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = ChatService();
  final _input = TextEditingController();
  late final Stream<List<ChatMessage>> _messages = _service.watchMessages(widget.student.uid);
  StreamSubscription<ChatThread?>? _threadSub;

  /// Séance en contexte, retirée après le premier envoi (ou par la croix).
  late String? _replySessionId = widget.sessionId;
  late String? _replySessionTitle = widget.sessionTitle;
  bool _sending = false;
  int _lastMarkedUnread = 0;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  /// Rôle du lecteur, lu une fois depuis le profil connecté.
  bool _asCoach = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _asCoach = CurrentUserScope.of(context).isCoach;
    // Écoute du résumé : tant que l'écran est ouvert, tout message reçu est marqué lu.
    _threadSub ??= _service.watchThread(widget.student.uid).listen(_markReadIfNeeded, onError: (_) {});
  }

  @override
  void dispose() {
    _threadSub?.cancel();
    _input.dispose();
    super.dispose();
  }


  /// L'écran est ouvert : tout ce qui arrive est lu.
  void _markReadIfNeeded(ChatThread? thread) {
    if (thread == null || !mounted) return;
    final unread = thread.unreadFor(coach: _asCoach);
    if (unread == 0 || unread == _lastMarkedUnread) return;
    _lastMarkedUnread = unread;
    _service
        .markRead(studentUid: widget.student.uid, coachUid: widget.coachUid, asCoach: _asCoach)
        .then((_) => _lastMarkedUnread = 0, onError: (_) => _lastMarkedUnread = 0);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final me = CurrentUserScope.of(context);
    final sessionId = _replySessionId;
    final sessionTitle = _replySessionTitle;
    setState(() {
      _sending = true;
      _replySessionId = null;
      _replySessionTitle = null;
    });
    _input.clear();
    try {
      await _service.sendMessage(
        studentUid: widget.student.uid,
        coachUid: widget.coachUid,
        sender: me,
        text: text,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
      );
    } catch (e) {
      if (!mounted) return;
      // On rend le texte (et le contexte) pour pouvoir réessayer.
      setState(() {
        _input.text = text;
        _replySessionId = sessionId;
        _replySessionTitle = sessionTitle;
      });
      showToast(context, friendlyErrorMessage(e), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = CurrentUserScope.of(context);
    final otherName = me.isCoach
        ? widget.student.nameOrEmail
        : ((widget.coachName?.trim().isNotEmpty ?? false) ? widget.coachName!.trim() : 'Mon coach');

    return Scaffold(
      appBar: AppBar(title: Text(AppText.upper(otherName))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: _messages,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(18),
                      child: ErrorCard(message: friendlyErrorMessage(snap.error!)),
                    );
                  }
                  if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snap.data ?? const <ChatMessage>[];
                  if (messages.isEmpty) return _EmptyChat(otherName: otherName, asCoach: me.isCoach);
                  return ChatMessageList(messages: messages, myUid: me.uid);
                },
              ),
            ),
            if (_replySessionTitle != null)
              _ReplyContext(
                title: _replySessionTitle!,
                onClear: () => setState(() {
                  _replySessionId = null;
                  _replySessionTitle = null;
                }),
              ),
            _Composer(
              controller: _input,
              sending: _sending,
              onSend: _input.text.trim().isEmpty ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}

/// Liste des messages, du plus récent (en bas) au plus ancien, avec séparateurs de jour.
/// Publique pour pouvoir être testée indépendamment de Firestore.
class ChatMessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final String myUid;
  const ChatMessageList({super.key, required this.messages, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Liste inversée : index 0 = message le plus récent, collé en bas de l'écran.
    final reversed = messages.reversed.toList();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      itemCount: reversed.length,
      itemBuilder: (context, i) {
        final m = reversed[i];
        final date = m.createdAt ?? now;
        final older = i + 1 < reversed.length ? reversed[i + 1] : null;
        final olderDate = older?.createdAt ?? now;
        final showDay = older == null || !isSameDay(date, olderDate);
        // Regroupe visuellement les messages consécutifs d'un même auteur.
        final sameAuthorAsOlder = older != null && older.senderId == m.senderId && !showDay;
        return Column(
          children: [
            if (showDay) _DaySeparator(date: date, now: now),
            _Bubble(message: m, mine: m.senderId == myUid, tight: sameAuthorAsOlder),
          ],
        );
      },
    );
  }
}

class _DaySeparator extends StatelessWidget {
  final DateTime date;
  final DateTime now;
  const _DaySeparator({required this.date, required this.now});

  @override
  Widget build(BuildContext context) {
    final String label;
    if (isSameDay(date, now)) {
      label = "Aujourd'hui";
    } else if (isSameDay(date, addDays(now, -1))) {
      label = 'Hier';
    } else {
      label = formatDayLong(date);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: AppText.caption.copyWith(fontSize: 11)),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool tight;
  const _Bubble({required this.message, required this.mine, required this.tight});

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(18);
    const small = Radius.circular(6);
    final m = message;
    return Padding(
      padding: EdgeInsets.only(top: tight ? 3 : 10),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: BoxDecoration(
              gradient: mine ? AppColors.buttonGradient : null,
              color: mine ? null : AppColors.card2,
              borderRadius: BorderRadius.only(
                topLeft: r,
                topRight: r,
                bottomLeft: mine ? r : small,
                bottomRight: mine ? small : r,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.sessionTitle != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: mine ? 0.18 : 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '💪 ${m.sessionTitle}',
                      style: AppText.caption.copyWith(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(m.text, style: AppText.bodyText.copyWith(color: Colors.white)),
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerRight,
                  child: m.pending
                      ? Icon(Icons.schedule, size: 12, color: Colors.white.withValues(alpha: 0.6))
                      : Text(
                          formatTime(m.createdAt!),
                          style: AppText.caption.copyWith(
                            fontSize: 10.5,
                            color: Colors.white.withValues(alpha: mine ? 0.75 : 0.5),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final String otherName;
  final bool asCoach;
  const _EmptyChat({required this.otherName, required this.asCoach});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💬', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(AppText.upper('Démarre la conversation'), style: AppText.barTitle, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              asCoach
                  ? 'Encourage $otherName, réponds à ses questions ou ajuste son programme.'
                  : 'Une question sur une séance ou ton alimentation ? Écris à $otherName.',
              textAlign: TextAlign.center,
              style: AppText.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyContext extends StatelessWidget {
  final String title;
  final VoidCallback onClear;
  const _ReplyContext({required this.title, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, size: 16, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text('À propos de : $title', style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 16, color: AppColors.muted),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback? onSend;
  const _Composer({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final enabled = onSend != null && !sending;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              maxLength: chatMaxLength,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.bodyText,
              decoration: const InputDecoration(
                hintText: 'Écris ton message…',
                counterText: '',
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: enabled ? 1 : 0.4,
            child: Material(
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: const BoxDecoration(gradient: AppColors.buttonGradient),
                child: InkWell(
                  onTap: enabled ? onSend : null,
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: sending
                        ? const Padding(
                            padding: EdgeInsets.all(13),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
