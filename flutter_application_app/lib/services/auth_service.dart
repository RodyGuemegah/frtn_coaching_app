import 'package:firebase_auth/firebase_auth.dart';

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
      return _signInMessage(e.code);
    } catch (_) {
      return 'Erreur de connexion, réessaie';
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
    _ => 'Erreur de connexion, réessaie',
  };
}
