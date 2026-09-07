import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/cartes.dart';

class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName?.trim().isNotEmpty ?? false) ? user!.displayName!.trim() : (user?.email ?? '');
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: AppColors.accentDark,
                child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              Text(name, style: const TextStyle(color: AppColors.text, fontSize: 19, fontWeight: FontWeight.w700)),
              if (user?.email != null && name != user!.email)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(user.email!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ),
            ],
          ),
        ),
        const SectionLabel('Mon coach'),
        const AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.card2,
                child: Icon(Icons.person, color: AppColors.muted),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text('Aucun coach assigné pour le moment', style: TextStyle(color: AppColors.muted, fontSize: 13)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GhostButton(label: 'Se déconnecter', onPressed: () => AuthService().signOut()),
      ],
    );
  }
}
