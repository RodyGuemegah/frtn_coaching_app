import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/chat_models.dart';

/// Messagerie coach ↔ élève : une conversation par élève.
///
/// - `users/{studentUid}/threads/coach`              → résumé (dernier message, non-lus)
/// - `users/{studentUid}/threads/coach/messages/{id}` → messages
class ChatService {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _thread(String studentUid) =>
      _db.doc('users/$studentUid/threads/coach');

  CollectionReference<Map<String, dynamic>> _messages(String studentUid) =>
      _thread(studentUid).collection('messages');

  /// Les 300 derniers messages, du plus ancien au plus récent, en direct.
  Stream<List<ChatMessage>> watchMessages(String studentUid) => _messages(studentUid)
      .orderBy('createdAt')
      .limitToLast(300)
      .snapshots()
      .map((snap) => snap.docs.map((d) => ChatMessage.fromDoc(d.id, d.data())).toList());

  /// Résumé d'une conversation (null tant qu'aucun message n'a été échangé).
  Stream<ChatThread?> watchThread(String studentUid) =>
      _thread(studentUid).snapshots().map((d) => d.exists ? ChatThread.fromDoc(d.data()!) : null);

  /// Toutes les conversations d'un coach (requête collectionGroup sur `threads`).
  Stream<List<ChatThread>> watchCoachThreads(String coachUid) => _db
      .collectionGroup('threads')
      .where('coachId', isEqualTo: coachUid)
      .snapshots()
      .map((snap) => snap.docs.map((d) => ChatThread.fromDoc(d.data())).toList());

  /// Envoie un message. Le message et le résumé (dernier message + compteur de
  /// non-lus du destinataire) sont écrits dans une seule opération atomique.
  Future<void> sendMessage({
    required String studentUid,
    required String coachUid,
    required AppUser sender,
    required String text,
    String? sessionId,
    String? sessionTitle,
  }) {
    final clean = text.trim();
    if (clean.isEmpty) return Future.value();
    final fromCoach = sender.isCoach;
    final message = ChatMessage(
      id: '',
      text: clean.length > chatMaxLength ? clean.substring(0, chatMaxLength) : clean,
      senderId: sender.uid,
      senderRole: fromCoach ? 'coach' : 'eleve',
      sessionId: sessionId,
      sessionTitle: sessionTitle,
    );

    final batch = _db.batch();
    batch.set(_messages(studentUid).doc(), {
      ...message.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _thread(studentUid),
      {
        'studentId': studentUid,
        'coachId': coachUid,
        'lastText': chatPreview(message.text, max: 140),
        'lastSenderRole': message.senderRole,
        'lastAt': FieldValue.serverTimestamp(),
        // +1 non-lu pour le destinataire ; l'expéditeur a forcément tout lu.
        if (fromCoach) 'unreadForStudent': FieldValue.increment(1) else 'unreadForCoach': FieldValue.increment(1),
        if (fromCoach) 'unreadForCoach': 0 else 'unreadForStudent': 0,
      },
      SetOptions(merge: true),
    );
    return batch.commit();
  }

  /// Remet à zéro le compteur de non-lus du lecteur (coach ou élève).
  Future<void> markRead({required String studentUid, required String coachUid, required bool asCoach}) {
    return _thread(studentUid).set({
      'studentId': studentUid,
      'coachId': coachUid,
      asCoach ? 'unreadForCoach' : 'unreadForStudent': 0,
    }, SetOptions(merge: true));
  }
}
