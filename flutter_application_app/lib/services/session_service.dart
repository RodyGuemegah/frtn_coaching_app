import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/session_model.dart';

class SessionService {
  Stream<List<SessionModel>> watchSessions() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users/$uid/sessions')
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SessionModel.fromDoc(d.id, d.data()))
            .toList());
  }

  Future<void> markDone(String sessionId) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .doc('users/$uid/sessions/$sessionId')
        .update({'status': 'done'});
  }
}