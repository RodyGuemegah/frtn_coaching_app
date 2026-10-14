import 'firestore_helpers.dart';

/// Un message de la conversation coach ↔ élève.
/// Stocké dans `users/{studentUid}/threads/coach/messages/{id}`.
class ChatMessage {
  final String id;
  final String text;
  final String senderId;

  /// 'coach' ou 'eleve'.
  final String senderRole;

  /// `null` tant que l'heure serveur n'est pas revenue (message en cours d'envoi).
  final DateTime? createdAt;

  /// Séance à laquelle le message fait référence (ex : réponse à un ressenti).
  final String? sessionId;
  final String? sessionTitle;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderRole,
    this.createdAt,
    this.sessionId,
    this.sessionTitle,
  });

  bool get fromCoach => senderRole == 'coach';

  /// Le message est-il en cours d'envoi (pas encore confirmé par le serveur) ?
  bool get pending => createdAt == null;

  factory ChatMessage.fromDoc(String id, Map<String, dynamic> m) => ChatMessage(
    id: id,
    text: parseString(m['text']),
    senderId: parseString(m['senderId']),
    senderRole: parseString(m['senderRole'], 'eleve'),
    createdAt: parseDate(m['createdAt']),
    sessionId: parseStringOrNull(m['sessionId']),
    sessionTitle: parseStringOrNull(m['sessionTitle']),
  );

  /// Champs persistés (sans `createdAt`, posé par le service via serverTimestamp).
  Map<String, dynamic> toMap() => {
    'text': text,
    'senderId': senderId,
    'senderRole': senderRole,
    if (sessionId != null) 'sessionId': sessionId,
    if (sessionTitle != null) 'sessionTitle': sessionTitle,
  };
}

/// Résumé d'une conversation (dernier message + compteurs de non-lus).
/// Stocké dans `users/{studentUid}/threads/coach`.
class ChatThread {
  final String studentId;
  final String coachId;
  final String lastText;
  final String? lastSenderRole;
  final DateTime? lastAt;
  final int unreadForCoach;
  final int unreadForStudent;

  const ChatThread({
    required this.studentId,
    required this.coachId,
    this.lastText = '',
    this.lastSenderRole,
    this.lastAt,
    this.unreadForCoach = 0,
    this.unreadForStudent = 0,
  });

  factory ChatThread.fromDoc(Map<String, dynamic> m) => ChatThread(
    studentId: parseString(m['studentId']),
    coachId: parseString(m['coachId']),
    lastText: parseString(m['lastText']),
    lastSenderRole: parseStringOrNull(m['lastSenderRole']),
    lastAt: parseDate(m['lastAt']),
    unreadForCoach: parseInt(m['unreadForCoach']),
    unreadForStudent: parseInt(m['unreadForStudent']),
  );

  int unreadFor({required bool coach}) => coach ? unreadForCoach : unreadForStudent;
}

/// Longueur maximale d'un message (également imposée par les règles Firestore).
const chatMaxLength = 2000;

/// Aperçu court du dernier message, pour les listes.
String chatPreview(String text, {int max = 80}) {
  final oneLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return oneLine.length <= max ? oneLine : '${oneLine.substring(0, max - 1)}…';
}
