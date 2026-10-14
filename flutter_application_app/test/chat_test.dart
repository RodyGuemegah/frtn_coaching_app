import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_app/models/chat_models.dart';
import 'package:flutter_application_app/screens/chat_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMessage', () {
    test('lit un message complet', () {
      final m = ChatMessage.fromDoc('m1', {
        'text': 'Bravo pour la séance !',
        'senderId': 'coach',
        'senderRole': 'coach',
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 14, 18, 42)),
        'sessionId': 's1',
        'sessionTitle': 'Haut du corps',
      });
      expect(m.fromCoach, isTrue);
      expect(m.pending, isFalse);
      expect(m.createdAt, DateTime(2026, 10, 14, 18, 42));
      expect(m.sessionTitle, 'Haut du corps');
    });

    test('un message sans heure serveur est « en cours d\'envoi »', () {
      final m = ChatMessage.fromDoc('m2', {'text': 'Salut', 'senderId': 'lucas', 'senderRole': 'eleve'});
      expect(m.pending, isTrue);
      expect(m.fromCoach, isFalse);
    });

    test('toMap n\'écrit ni createdAt ni la séance si absente', () {
      const m = ChatMessage(id: '', text: 'Hey', senderId: 'lucas', senderRole: 'eleve');
      final map = m.toMap();
      expect(map.containsKey('createdAt'), isFalse);
      expect(map.containsKey('sessionId'), isFalse);
      expect(map['senderRole'], 'eleve');
    });
  });

  test('ChatThread : compteurs de non-lus par rôle', () {
    final t = ChatThread.fromDoc({'studentId': 'lucas', 'coachId': 'coach', 'unreadForCoach': 3, 'unreadForStudent': 0});
    expect(t.unreadFor(coach: true), 3);
    expect(t.unreadFor(coach: false), 0);
  });

  test('chatPreview : une ligne, tronquée', () {
    expect(chatPreview('Ligne 1\n\nLigne   2'), 'Ligne 1 Ligne 2');
    expect(chatPreview('a' * 100, max: 10), '${'a' * 9}…');
  });

  testWidgets('ChatMessageList : séparateur de jour et messages des deux côtés', (tester) async {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final messages = [
      ChatMessage(id: '1', text: 'Séance faite, c\'était dur', senderId: 'lucas', senderRole: 'eleve', createdAt: yesterday),
      ChatMessage(id: '2', text: 'Bravo, on ajuste la charge', senderId: 'coach', senderRole: 'coach', createdAt: today),
      const ChatMessage(id: '3', text: 'Merci !', senderId: 'lucas', senderRole: 'eleve'), // en cours d'envoi
    ];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ChatMessageList(messages: messages, myUid: 'coach'))));

    expect(find.text("Séance faite, c'était dur"), findsOneWidget);
    expect(find.text('Bravo, on ajuste la charge'), findsOneWidget);
    expect(find.text('Hier'), findsOneWidget);
    expect(find.text("Aujourd'hui"), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget, reason: 'le message non confirmé affiche une horloge');
  });
}
