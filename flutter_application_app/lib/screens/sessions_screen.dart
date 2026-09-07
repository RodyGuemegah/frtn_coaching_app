import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../services/session_service.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes séances')),
      body: StreamBuilder<List<SessionModel>>(
        stream: SessionService().watchSessions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          final sessions = snapshot.data ?? [];
          if (sessions.isEmpty) {
            return const Center(child: Text('Aucune séance pour le moment'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, i) {
              final s = sessions[i];
              return Card(
                child: ListTile(
                  title: Text(s.title),
                  subtitle: Text('${s.date.day}/${s.date.month} · ${s.exercises.length} exercices'),
                  trailing: s.status == 'done'
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
      ),
    );
  }
}