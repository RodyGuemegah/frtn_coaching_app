import 'package:flutter/services.dart';

/// Bornes réalistes des données physiques d'un élève.
/// Centralisées ici pour être réutilisées (création d'élève, édition de profil…).
class ProfileLimits {
  ProfileLimits._();

  static const minAge = 10;
  static const maxAge = 100;
  static const minHeightCm = 100;
  static const maxHeightCm = 250;
  static const minWeightKg = 25;
  static const maxWeightKg = 300;
}

/// Parse un nombre saisi par l'utilisateur (accepte la virgule décimale).
num? parseUserNumber(String? v) {
  final s = (v ?? '').trim().replaceAll(',', '.');
  if (s.isEmpty) return null;
  return num.tryParse(s);
}

/// Validateur d'un entier optionnel compris entre [min] et [max] (inclus).
String? Function(String?) optionalIntInRange(int min, int max, String unit) {
  return (v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final n = int.tryParse(s);
    if (n == null) return 'Nombre entier';
    if (n < min || n > max) return 'Entre $min et $max$unit';
    return null;
  };
}

/// Validateur d'un nombre décimal optionnel compris entre [min] et [max] (inclus).
String? Function(String?) optionalNumInRange(num min, num max, String unit) {
  return (v) {
    if ((v ?? '').trim().isEmpty) return null;
    final n = parseUserNumber(v);
    if (n == null) return 'Nombre';
    if (n < min || n > max) return 'Entre $min et $max$unit';
    return null;
  };
}

String? ageValidator(String? v) => optionalIntInRange(ProfileLimits.minAge, ProfileLimits.maxAge, ' ans')(v);
String? heightValidator(String? v) =>
    optionalIntInRange(ProfileLimits.minHeightCm, ProfileLimits.maxHeightCm, ' cm')(v);
String? weightValidator(String? v) =>
    optionalNumInRange(ProfileLimits.minWeightKg, ProfileLimits.maxWeightKg, ' kg')(v);

/// Filtres de saisie : empêchent de taper autre chose que des chiffres
/// (et limitent la longueur), en amont de la validation.
List<TextInputFormatter> intInput({int maxDigits = 3}) => [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(maxDigits),
];

/// Décimal avec au plus 1 chiffre après la virgule (ex : 72,5).
List<TextInputFormatter> decimalInput({int maxIntDigits = 3}) => [
  FilteringTextInputFormatter.allow(RegExp('^\\d{0,$maxIntDigits}([.,]\\d?)?')),
];
