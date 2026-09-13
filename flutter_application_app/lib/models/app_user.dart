import 'firestore_helpers.dart';

enum UserRole {
  coach('coach'),
  eleve('eleve');

  final String key;
  const UserRole(this.key);

  /// Tout ce qui n'est pas explicitement 'coach' est traité comme élève.
  static UserRole fromKey(String? key) => key == 'coach' ? UserRole.coach : UserRole.eleve;
}

/// Profil applicatif stocké dans `users/{uid}`.
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String firstName;
  final String lastName;
  final UserRole role;
  final String? coachId;
  final String? coachName;
  final DateTime? createdAt;
  final int? age;
  final int? heightCm;
  final num? weightKg;
  final String? goal;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.firstName = '',
    this.lastName = '',
    this.role = UserRole.eleve,
    this.coachId,
    this.coachName,
    this.createdAt,
    this.age,
    this.heightCm,
    this.weightKg,
    this.goal,
  });

  bool get isCoach => role == UserRole.coach;

  /// "LM" pour Lucas Martin ; sinon première lettre du nom affiché ou de l'email.
  String get initials {
    final f = firstName.trim();
    final l = lastName.trim();
    if (f.isNotEmpty && l.isNotEmpty) return '${f[0]}${l[0]}'.toUpperCase();
    final source = displayName.trim().isNotEmpty ? displayName.trim() : email;
    return source.isNotEmpty ? source[0].toUpperCase() : '?';
  }

  /// Prénom, ou premier mot du nom affiché, ou début de l'email.
  String get shortName {
    if (firstName.trim().isNotEmpty) return firstName.trim();
    if (displayName.trim().isNotEmpty) return displayName.trim().split(' ').first;
    return email.split('@').first;
  }

  /// Nom à afficher : displayName, sinon email.
  String get nameOrEmail => displayName.trim().isNotEmpty ? displayName.trim() : email;

  factory AppUser.fromDoc(String id, Map<String, dynamic> data) {
    return AppUser(
      uid: id,
      email: parseString(data['email']),
      displayName: parseString(data['displayName']),
      firstName: parseString(data['firstName']),
      lastName: parseString(data['lastName']),
      role: UserRole.fromKey(parseStringOrNull(data['role'])),
      coachId: parseStringOrNull(data['coachId']),
      coachName: parseStringOrNull(data['coachName']),
      createdAt: parseDate(data['createdAt']),
      age: parseIntOrNull(data['age']),
      heightCm: parseIntOrNull(data['heightCm']),
      weightKg: parseNumOrNull(data['weightKg']),
      goal: parseStringOrNull(data['goal']),
    );
  }

  /// Profil par défaut quand aucun document `users/{uid}` n'existe encore
  /// (comptes créés avant l'introduction des rôles) : élève sans coach.
  factory AppUser.fallback({required String uid, String? email, String? displayName}) {
    return AppUser(uid: uid, email: email ?? '', displayName: displayName ?? '');
  }

  /// Champs persistés (sans `createdAt`, posé côté service via serverTimestamp).
  Map<String, dynamic> toMap() => {
    'email': email,
    'displayName': displayName,
    'firstName': firstName,
    'lastName': lastName,
    'role': role.key,
    if (coachId != null) 'coachId': coachId,
    if (coachName != null) 'coachName': coachName,
    if (age != null) 'age': age,
    if (heightCm != null) 'heightCm': heightCm,
    if (weightKg != null) 'weightKg': weightKg,
    if (goal != null) 'goal': goal,
  };
}
