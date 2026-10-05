import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text.dart';

/// Thème sombre de l'app (palette + charte typographique de la maquette),
/// partagé par l'app et les previews.
ThemeData buildAppTheme() {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: width == 0 ? BorderSide.none : BorderSide(color: color, width: width),
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AppText.body,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent, brightness: Brightness.dark),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: AppText.textTheme(base.textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.accent,
      centerTitle: true,
      titleTextStyle: AppText.barTitle,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.panel,
      indicatorColor: AppColors.accent.withValues(alpha: 0.16),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? AppColors.accent : AppColors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: AppText.body,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? AppColors.accent : AppColors.muted,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
      iconColor: Colors.white.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(Colors.transparent, 0),
      focusedBorder: border(AppColors.accent, 1.4),
      errorBorder: border(Colors.redAccent, 1.2),
      focusedErrorBorder: border(Colors.redAccent, 1.4),
    ),
    // Dialogues : panneau sombre, coins arrondis, bordure, titre charte.
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.border),
      ),
      titleTextStyle: AppText.barTitle,
      contentTextStyle: AppText.bodyText.copyWith(color: AppColors.muted),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.border,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      textStyle: AppText.bodyText,
    ),
    // Repli pour tout SnackBar non passé par showToast().
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.card2,
      contentTextStyle: AppText.bodyText,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent2,
        textStyle: const TextStyle(fontFamily: AppText.body, fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.accent : Colors.transparent,
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
  );
}
