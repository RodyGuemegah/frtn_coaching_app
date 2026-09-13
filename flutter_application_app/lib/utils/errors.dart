import 'package:firebase_auth/firebase_auth.dart';

/// Transforme une erreur Firebase en message lisible pour l'utilisateur.
String friendlyErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'network-request-failed' => 'Pas de connexion réseau.',
      'too-many-requests' => 'Trop de tentatives, réessaie plus tard.',
      _ => "Erreur d'authentification (${error.code}).",
    };
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => 'Accès refusé. Vérifie que ton compte est bien configuré.',
      'failed-precondition' => 'Index Firestore en cours de création, réessaie dans quelques minutes.',
      'unavailable' => 'Service indisponible, vérifie ta connexion.',
      _ => 'Impossible de charger les données (${error.code}).',
    };
  }
  return 'Impossible de charger les données.';
}
