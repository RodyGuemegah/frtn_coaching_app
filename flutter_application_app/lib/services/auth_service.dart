import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Retourne `null` en cas de succès, sinon un message d'erreur affichable.
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService.signIn] FirebaseAuthException code=${e.code} message=${e.message}');
      return _signInMessage(e.code);
    } catch (e, st) {
      debugPrint('[AuthService.signIn] Erreur inattendue: $e\n$st');
      return 'Erreur de connexion, réessaie ($e)';
    }
  }

  /// Envoi de l'email de (ré)initialisation du mot de passe.
  /// Retourne `null` si l'envoi est accepté — y compris si le compte n'existe pas
  /// (on ne révèle pas l'existence d'un compte).
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'user-not-found' => null,
        'invalid-email' => 'Adresse email invalide',
        'network-request-failed' => 'Pas de connexion réseau',
        'too-many-requests' => 'Trop de tentatives, réessaie plus tard',
        _ => 'Envoi impossible, réessaie',
      };
    } catch (_) {
      return 'Envoi impossible, réessaie';
    }
  }

  Future<void> signOut() => _auth.signOut();

  static String _signInMessage(String code) => switch (code) {
    'user-not-found' || 'wrong-password' || 'invalid-credential' || 'invalid-email' =>
      'Email ou mot de passe incorrect',
    'user-disabled' => 'Ce compte a été désactivé',
    'too-many-requests' => 'Trop de tentatives, réessaie plus tard',
    'network-request-failed' => 'Pas de connexion réseau',
    'operation-not-allowed' => 'Connexion email/mot de passe désactivée dans Firebase',
    // macOS / iOS : Firebase Auth n'arrive pas à écrire la session dans le trousseau.
    'keychain-error' => 'Accès au trousseau refusé (macOS) : active « Keychain Sharing » dans Xcode',
    // Code inconnu : on l'affiche pour pouvoir diagnostiquer.
    _ => 'Erreur de connexion, réessaie ($code)',
  };
}
