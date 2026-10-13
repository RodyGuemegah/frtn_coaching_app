import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_app/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un profil sans champ archived est actif', () {
    final u = AppUser.fromDoc('lucas', {'email': 'l@t.fr', 'displayName': 'Lucas Martin', 'role': 'eleve'});
    expect(u.archived, isFalse);
    expect(u.archivedAt, isNull);
  });

  test('lit archived et archivedAt', () {
    final u = AppUser.fromDoc('emma', {
      'email': 'e@t.fr',
      'displayName': 'Emma Bertrand',
      'archived': true,
      'archivedAt': Timestamp.fromDate(DateTime(2026, 10, 14)),
    });
    expect(u.archived, isTrue);
    expect(u.archivedAt, DateTime(2026, 10, 14));
  });

  test("archived n'est jamais écrit par toMap (géré par setArchived)", () {
    const u = AppUser(uid: 'x', email: 'x@t.fr', displayName: 'X', archived: true);
    expect(u.toMap().containsKey('archived'), isFalse);
  });
}
