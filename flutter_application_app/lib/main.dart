import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'models/app_user.dart';
import 'screens/coach/coach_home.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';
import 'utils/errors.dart';
import 'widgets/cartes.dart';
import 'widgets/current_user_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FRTN Coaching',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}

/// Étape 1 : état d'authentification Firebase → Login ou RoleGate.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Stream<User?> _auth = AuthService().authStateChanges;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _FullScreenMessage(
            message: friendlyErrorMessage(snapshot.error!),
            action: GhostButton(
              label: 'Réessayer',
              onPressed: () => setState(() => _auth = AuthService().authStateChanges),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) return const _Splash();
        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        return RoleGate(key: ValueKey(user.uid), user: user);
      },
    );
  }
}

/// Étape 2 : profil Firestore (`users/{uid}`) → espace coach ou espace élève.
/// Sans document (compte historique), l'utilisateur est traité comme élève.
class RoleGate extends StatefulWidget {
  final User user;
  const RoleGate({super.key, required this.user});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  late final Stream<AppUser?> _profile = UserService().watchUser(widget.user.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _profile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _FullScreenMessage(
            message: friendlyErrorMessage(snapshot.error!),
            action: GhostButton(label: 'Se déconnecter', onPressed: () => AuthService().signOut()),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) return const _Splash();
        final profile = snapshot.data ??
            AppUser.fallback(
              uid: widget.user.uid,
              email: widget.user.email,
              displayName: widget.user.displayName,
            );
        return CurrentUserScope(
          user: profile,
          child: profile.isCoach ? const CoachShell() : const HomeScreen(),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _FullScreenMessage extends StatelessWidget {
  final String message;
  final Widget action;
  const _FullScreenMessage({required this.message, required this.action});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ErrorCard(message: message),
                const SizedBox(height: 16),
                action,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
