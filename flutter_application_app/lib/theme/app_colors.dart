import 'package:flutter/material.dart';

/// Palette calquée sur la maquette FRTN Coaching.
class AppColors {
  AppColors._();

  static const background = Color(0xFF0A0A0C);
  static const panel = Color(0xFF141417);
  static const card = Color(0xFF1A1A1F);
  static const card2 = Color(0xFF26262C);
  static const border = Color(0xFF2C2C33);

  static const accent = Color(0xFFE8192C);
  static const accentDark = Color(0xFF8F0E1A);
  static const accentDark2 = Color(0xFFA30F1E);
  static const accent2 = Color(0xFFFF5560);

  static const text = Color(0xFFF5F5F7);
  static const muted = Color(0xFF9A9AA3);

  static const accentGradient = LinearGradient(
    colors: [accent, accentDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const buttonGradient = LinearGradient(
    colors: [accent, accentDark2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const progressGradient = LinearGradient(colors: [accent, accent2]);
}
