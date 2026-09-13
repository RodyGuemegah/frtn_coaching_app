import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/cartes.dart';
import '../widgets/current_user_scope.dart';

class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = CurrentUserScope.of(context);
    final details = <String>[
      if (user.age != null) '${user.age} ans',
      if (user.heightCm != null) '${(user.heightCm! / 100).toStringAsFixed(2).replaceAll('.', ',')} m',
      if (user.weightKg != null) '${_formatNum(user.weightKg!)} kg',
    ];
    final coachName = user.coachName?.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      children: [
        Center(
          child: Column(
            children: [
              InitialsAvatar(user.initials, radius: 42),
              const SizedBox(height: 12),
              Text(user.nameOrEmail, style: const TextStyle(color: AppColors.text, fontSize: 19, fontWeight: FontWeight.w700)),
              if (user.nameOrEmail != user.email && user.email.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(user.email, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ),
              if (details.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(details.join(' · '), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ),
            ],
          ),
        ),
        if (user.goal != null) ...[
          const SectionLabel('Objectif du programme'),
          AppCard(
            child: Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(child: Text(user.goal!, style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
        ],
        const SectionLabel('Mon coach'),
        AppCard(
          child: Row(
            children: [
              if (coachName != null && coachName.isNotEmpty)
                InitialsAvatar(_initialsOf(coachName), radius: 20, style: AvatarStyle.bordered)
              else
                const CircleAvatar(radius: 20, backgroundColor: AppColors.card2, child: Icon(Icons.person, color: AppColors.muted)),
              const SizedBox(width: 12),
              Expanded(
                child: coachName != null && coachName.isNotEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(coachName, style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          const Text('Préparation physique & nutrition', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        ],
                      )
                    : const Text('Aucun coach assigné pour le moment', style: TextStyle(color: AppColors.muted, fontSize: 13)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GhostButton(label: 'Se déconnecter', onPressed: () => AuthService().signOut()),
      ],
    );
  }

  static String _formatNum(num n) => (n % 1 == 0 ? n.toInt().toString() : n.toString()).replaceAll('.', ',');

  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
