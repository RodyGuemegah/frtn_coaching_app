import 'package:flutter/widgets.dart';
import '../models/app_user.dart';

/// Expose le profil de l'utilisateur connecté à tout l'arbre (remplace les
/// accès directs à `FirebaseAuth.instance.currentUser` dans les écrans).
class CurrentUserScope extends InheritedWidget {
  final AppUser user;

  const CurrentUserScope({super.key, required this.user, required super.child});

  static AppUser of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CurrentUserScope>();
    assert(scope != null, 'CurrentUserScope manquant au-dessus de ce widget');
    return scope!.user;
  }

  static AppUser? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CurrentUserScope>()?.user;

  @override
  bool updateShouldNotify(CurrentUserScope oldWidget) => oldWidget.user != user;
}
