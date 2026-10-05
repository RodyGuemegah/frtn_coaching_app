import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Charte typographique officielle FRTN Coaching (issue de la maquette).
///
/// Règles :
/// - **Titres** (écrans, cartes héros, dialogues) : Barlow Condensed, italique,
///   extra-gras 800, MAJUSCULES, léger espacement — `h1,h2` de la maquette.
/// - **Boutons** : Barlow Condensed italique 800 en MAJUSCULES — `.btn`.
/// - **Chiffres clés** (stats, kcal) : Barlow Condensed italique 800.
/// - **Libellés de section** : Inter 700 en MAJUSCULES espacées — `.sect`.
/// - **Textes courants** : Inter.
///
/// Les styles « titre » ne transforment pas le texte : passer par [AppText.upper]
/// (ou les widgets [ScreenTitle] / [CardTitle]) pour les majuscules.
class AppText {
  AppText._();

  static const display = 'BarlowCondensed';
  static const body = 'Inter';

  /// Titre d'écran (« ESPACE COACH », « MES SÉANCES »).
  static const screenTitle = TextStyle(
    fontFamily: display,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w800,
    fontSize: 28,
    height: 1.05,
    letterSpacing: 0.5,
    color: AppColors.text,
  );

  /// Titre de carte importante / de séance (« HAUT DU CORPS — FORCE »).
  static const heroTitle = TextStyle(
    fontFamily: display,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w800,
    fontSize: 22,
    height: 1.1,
    letterSpacing: 0.4,
    color: AppColors.text,
  );

  /// Titre d'AppBar, de dialogue ou de bottom sheet.
  static const barTitle = TextStyle(
    fontFamily: display,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w800,
    fontSize: 21,
    letterSpacing: 0.5,
    color: AppColors.text,
  );

  /// Libellé de bouton.
  static const button = TextStyle(
    fontFamily: display,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w800,
    fontSize: 17,
    letterSpacing: 0.6,
    color: Colors.white,
  );

  /// Chiffre clé (StatTile, totaux kcal…).
  static const number = TextStyle(
    fontFamily: display,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w800,
    fontSize: 26,
    height: 1.1,
    color: AppColors.accent,
  );

  /// Libellé de section (« MES ÉLÈVES »).
  static const section = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w700,
    fontSize: 12.5,
    letterSpacing: 1.0,
    color: AppColors.muted,
  );

  /// Titre d'élément de liste (nom d'élève, de repas, de séance dans une liste).
  static const itemTitle = TextStyle(
    fontFamily: body,
    fontWeight: FontWeight.w700,
    fontSize: 15,
    color: AppColors.text,
  );

  /// Texte courant.
  static const bodyText = TextStyle(fontFamily: body, fontSize: 14, height: 1.4, color: AppColors.text);

  /// Sous-titre / texte secondaire.
  static const caption = TextStyle(fontFamily: body, fontSize: 12, height: 1.35, color: AppColors.muted);

  /// Majuscules françaises (gère les accents : « séance » → « SÉANCE »).
  static String upper(String s) => s.toUpperCase();

  /// TextTheme Material branché sur la charte (pour les widgets standards).
  static TextTheme textTheme(TextTheme base) {
    return base
        .apply(fontFamily: body, bodyColor: AppColors.text, displayColor: AppColors.text)
        .copyWith(
          titleLarge: barTitle,
          headlineSmall: barTitle,
          labelLarge: const TextStyle(fontFamily: body, fontWeight: FontWeight.w600, fontSize: 14),
        );
  }
}

/// Titre d'écran conforme à la charte, avec sous-titre optionnel.
class ScreenTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const ScreenTitle(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppText.upper(title), style: AppText.screenTitle),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!, style: AppText.caption),
        ],
      ],
    );
  }
}
