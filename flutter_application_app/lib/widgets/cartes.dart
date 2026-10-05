import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Carte de base au style de la maquette (fond + bordure arrondie).
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Decoration? decoration;
  final EdgeInsetsGeometry padding;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.decoration,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: decoration ??
          BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// Petite tuile de statistique (valeur + libellé), utilisée en grille 2x2.
class StatTile extends StatelessWidget {
  final String value;
  final String label;

  const StatTile({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: AppText.number),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: AppText.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

/// Titre de section en majuscules (ex: "OBJECTIF DU PROGRAMME").
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(AppText.upper(text), style: AppText.section),
    );
  }
}

/// Encadré d'information / avertissement (non bloquant), distinct d'une erreur.
class NoticeCard extends StatelessWidget {
  final String message;
  final IconData icon;
  const NoticeCard(this.message, {super.key, this.icon = Icons.info_outline_rounded});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.muted, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppText.caption.copyWith(fontSize: 12.5, color: AppColors.text))),
        ],
      ),
    );
  }
}

/// Bouton principal en dégradé, façon maquette (italique/majuscules).
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const PrimaryButton({super.key, required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null && !loading;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: SizedBox(
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: AppColors.buttonGradient,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: loading ? null : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(AppText.upper(label), style: AppText.button),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// Carte d'erreur (bordure accent) avec bouton « Réessayer » optionnel.
class ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorCard({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.text, fontSize: 13))),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Réessayer', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

/// Ligne d'exercice numérotée (badge + nom + détail), façon maquette.
class ExerciseRow extends StatelessWidget {
  final int index;
  final String name;
  final String detail;
  final Widget? trailing;
  final VoidCallback? onTap;

  const ExerciseRow({
    super.key,
    required this.index,
    required this.name,
    required this.detail,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: onTap,
        decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: AppColors.card2, borderRadius: BorderRadius.circular(9)),
              alignment: Alignment.center,
              child: Text('$index', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: AppColors.text, fontSize: 14.5, fontWeight: FontWeight.w700)),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(detail, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

enum AvatarStyle { accent, grey, bordered }

/// Avatar rond avec initiales, façon maquette (variantes accent / grise / bordée).
class InitialsAvatar extends StatelessWidget {
  final String initials;
  final double radius;
  final AvatarStyle style;

  const InitialsAvatar(this.initials, {super.key, this.radius = 21, this.style = AvatarStyle.accent});

  @override
  Widget build(BuildContext context) {
    late final Gradient gradient;
    Border? border;
    switch (style) {
      case AvatarStyle.accent:
        gradient = const LinearGradient(colors: [AppColors.accent, AppColors.accentDark]);
        break;
      case AvatarStyle.grey:
        gradient = const LinearGradient(colors: [Color(0xFF55555E), Color(0xFF2C2C33)]);
        break;
      case AvatarStyle.bordered:
        gradient = const LinearGradient(colors: [Color(0xFF3A3A42), Color(0xFF0F0F12)]);
        border = Border.all(color: AppColors.accent, width: 2);
        break;
    }
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient, border: border),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: radius * 0.62),
      ),
    );
  }
}

/// Bouton secondaire ("ghost"), fond carte + bordure.
class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const GhostButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.card,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: AppText.bodyText.copyWith(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
