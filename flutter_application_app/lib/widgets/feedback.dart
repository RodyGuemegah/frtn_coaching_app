import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'cartes.dart';

// Retours visuels de l'app, aux couleurs de la charte :
// - showToast           : bandeau flottant (succès / erreur / info) pour les actions courantes
// - showSuccessSheet    : feuille de succès animée pour les « grands moments »
// - showConfirmDialog   : confirmation (suppression…) stylisée

enum ToastType { success, error, info }

const _successColor = Color(0xFF2FD07A);

({IconData icon, Color color}) _toastLook(ToastType type) => switch (type) {
  ToastType.success => (icon: Icons.check_rounded, color: _successColor),
  ToastType.error => (icon: Icons.priority_high_rounded, color: AppColors.accent),
  ToastType.info => (icon: Icons.info_outline_rounded, color: AppColors.muted),
};

/// Bandeau flottant brandé. Remplace les SnackBar génériques.
void showToast(BuildContext context, String message, {ToastType type = ToastType.success}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final look = _toastLook(type);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      duration: Duration(milliseconds: type == ToastType.error ? 4500 : 2800),
      content: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.card2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: look.color.withValues(alpha: 0.55)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: look.color.withValues(alpha: 0.16), shape: BoxShape.circle),
              child: Icon(look.icon, color: look.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: AppText.bodyText.copyWith(fontWeight: FontWeight.w500))),
          ],
        ),
      ),
    ));
}

/// Feuille de succès plein écran (bas), avec icône animée.
/// À réserver aux étapes marquantes : compte créé, séance terminée…
Future<void> showSuccessSheet(
  BuildContext context, {
  required String title,
  required String message,
  String emoji = '✓',
  String buttonLabel = 'Continuer',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.elasticOut,
              builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
              child: Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.accentGradient,
                  boxShadow: [
                    BoxShadow(color: AppColors.accent.withValues(alpha: 0.45), blurRadius: 30, offset: const Offset(0, 10)),
                  ],
                ),
                child: emoji == '✓'
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 46)
                    : Text(emoji, style: const TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 20),
            Text(AppText.upper(title), textAlign: TextAlign.center, style: AppText.heroTitle.copyWith(fontSize: 26)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: AppText.bodyText.copyWith(color: AppColors.muted)),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: PrimaryButton(label: buttonLabel, onPressed: () => Navigator.of(ctx).pop())),
          ],
        ),
      ),
    ),
  );
}

/// Dialogue de confirmation stylisé. Retourne `true` si l'utilisateur confirme.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  bool destructive = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (destructive ? AppColors.accent : AppColors.muted).withValues(alpha: 0.14),
                ),
                child: Icon(
                  destructive ? Icons.delete_outline_rounded : Icons.help_outline_rounded,
                  color: destructive ? AppColors.accent : AppColors.text,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(AppText.upper(title), textAlign: TextAlign.center, style: AppText.barTitle),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: AppText.bodyText.copyWith(color: AppColors.muted)),
            const SizedBox(height: 20),
            PrimaryButton(label: confirmLabel, onPressed: () => Navigator.of(ctx).pop(true)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelLabel, style: const TextStyle(color: AppColors.muted)),
            ),
          ],
        ),
      ),
    ),
  );
  return ok == true;
}
