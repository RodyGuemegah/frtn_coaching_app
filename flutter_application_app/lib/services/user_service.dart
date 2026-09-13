import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';

class StudentCreationException implements Exception {
  final String message;
  const StudentCreationException(this.message);
  @override
  String toString() => message;
}

class StudentCreationResult {
  final AppUser student;

  /// `false` si le compte est créé mais que l'email de définition du mot de passe
  /// n'a pas pu partir (le coach peut le renvoyer depuis « Mot de passe oublié »).
  final bool resetEmailSent;
  const StudentCreationResult({required this.student, required this.resetEmailSent});
}

/// Profils `users/{uid}` + provisioning des comptes élèves.
class UserService {
  static const _provisioningAppName = 'student-provisioning';
  static Future<FirebaseApp>? _provisioningApp;

  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.doc('users/$uid');

  /// Profil de l'utilisateur ; `null` si aucun document n'existe (compte historique).
  Stream<AppUser?> watchUser(String uid) =>
      _doc(uid).snapshots().map((s) => s.exists ? AppUser.fromDoc(s.id, s.data()!) : null);

  Future<AppUser?> getUser(String uid) async {
    final s = await _doc(uid).get();
    return s.exists ? AppUser.fromDoc(s.id, s.data()!) : null;
  }

  /// Élèves rattachés à un coach, triés par nom (tri client : pas d'index composite requis).
  Stream<List<AppUser>> watchMyStudents(String coachUid) => _db
      .collection('users')
      .where('coachId', isEqualTo: coachUid)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map((d) => AppUser.fromDoc(d.id, d.data())).toList()
          ..sort((a, b) => a.nameOrEmail.toLowerCase().compareTo(b.nameOrEmail.toLowerCase()));
        return list;
      });

  Future<void> updateProfile(String uid, Map<String, dynamic> patch) => _doc(uid).update(patch);

  /// Crée un compte élève SANS déconnecter le coach, grâce à une seconde
  /// instance Firebase dédiée (`FirebaseAuth.instanceFor`). Le profil Firestore
  /// est écrit depuis la session du coach (seule autorisée par les règles), puis
  /// un email de définition de mot de passe est envoyé à l'élève.
  Future<StudentCreationResult> createStudent({
    required AppUser coach,
    required String firstName,
    required String lastName,
    required String email,
    int? age,
    int? heightCm,
    num? weightKg,
    String? goal,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanFirst = firstName.trim();
    final cleanLast = lastName.trim();
    final displayName = '$cleanFirst $cleanLast'.trim();

    final app = await _getProvisioningApp();
    final secondaryAuth = FirebaseAuth.instanceFor(app: app);

    try {
      final User newUser;
      try {
        final cred = await secondaryAuth.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: _randomPassword(),
        );
        newUser = cred.user!;
      } on FirebaseAuthException catch (e) {
        throw StudentCreationException(_authMessage(e.code));
      } on StudentCreationException {
        rethrow;
      } catch (_) {
        throw const StudentCreationException('Création du compte impossible, réessaie.');
      }

      final profile = AppUser(
        uid: newUser.uid,
        email: cleanEmail,
        displayName: displayName,
        firstName: cleanFirst,
        lastName: cleanLast,
        role: UserRole.eleve,
        coachId: coach.uid,
        coachName: coach.nameOrEmail,
        age: age,
        heightCm: heightCm,
        weightKg: weightKg,
        goal: goal?.trim().isEmpty == true ? null : goal?.trim(),
      );

      try {
        // Nom affiché côté Auth (facultatif : ne doit jamais bloquer la création).
        try {
          await newUser.updateDisplayName(displayName);
        } catch (_) {}
        // Écriture depuis l'instance PRIMAIRE (session coach).
        await _doc(newUser.uid).set({
          ...profile.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Rollback : ne pas laisser un compte Auth sans profil.
        try {
          await newUser.delete();
        } catch (_) {
          throw const StudentCreationException(
            "Le compte a été créé mais son profil n'a pas pu être enregistré. "
            'Supprime-le dans la console Firebase (Authentication) puis réessaie.',
          );
        }
        throw StudentCreationException(_firestoreMessage(e));
      }

      bool emailSent = true;
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: cleanEmail);
      } catch (_) {
        emailSent = false;
      }

      return StudentCreationResult(student: profile, resetEmailSent: emailSent);
    } finally {
      // Ne jamais laisser la session de l'élève ouverte sur l'instance secondaire.
      try {
        await secondaryAuth.signOut();
      } catch (_) {}
    }
  }

  static Future<FirebaseApp> _getProvisioningApp() {
    return _provisioningApp ??= () async {
      for (final app in Firebase.apps) {
        if (app.name == _provisioningAppName) return app;
      }
      return Firebase.initializeApp(
        name: _provisioningAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }();
  }

  /// Mot de passe temporaire jamais communiqué : l'élève en choisit un via l'email de réinitialisation.
  static String _randomPassword() {
    const lower = 'abcdefghijkmnpqrstuvwxyz';
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const digits = '23456789';
    const symbols = '!@#%&*?';
    const all = lower + upper + digits + symbols;
    final rng = Random.secure();
    String pick(String s) => s[rng.nextInt(s.length)];
    final chars = [pick(lower), pick(upper), pick(digits), pick(symbols)];
    while (chars.length < 24) {
      chars.add(pick(all));
    }
    chars.shuffle(rng);
    return chars.join();
  }

  static String _authMessage(String code) => switch (code) {
    'email-already-in-use' => 'Un compte existe déjà avec cet email.',
    'invalid-email' => 'Adresse email invalide.',
    'weak-password' => 'Mot de passe généré refusé, réessaie.',
    'operation-not-allowed' => 'La connexion par email/mot de passe est désactivée dans Firebase.',
    'network-request-failed' => 'Pas de connexion réseau.',
    'too-many-requests' => 'Trop de créations récentes, réessaie plus tard.',
    _ => 'Création du compte impossible ($code).',
  };

  static String _firestoreMessage(Object e) {
    if (e is FirebaseException && e.code == 'permission-denied') {
      return "Accès refusé : ton compte n'est pas reconnu comme coach (règles Firestore).";
    }
    return "Enregistrement du profil impossible, réessaie.";
  }
}
