import 'package:flutter/services.dart';
import 'package:flutter_application_app/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

String _format(List<TextInputFormatter> formatters, String typed) {
  var value = TextEditingValue.empty;
  for (final ch in typed.split('')) {
    var next = TextEditingValue(
      text: value.text + ch,
      selection: TextSelection.collapsed(offset: value.text.length + 1),
    );
    for (final f in formatters) {
      next = f.formatEditUpdate(value, next);
    }
    value = next;
  }
  return value.text;
}

void main() {
  group('bornes', () {
    test('âge', () {
      expect(ageValidator(''), isNull);
      expect(ageValidator('25'), isNull);
      expect(ageValidator('10'), isNull);
      expect(ageValidator('100'), isNull);
      expect(ageValidator('9'), 'Entre 10 et 100 ans');
      expect(ageValidator('182'), 'Entre 10 et 100 ans');
      expect(ageValidator('2a'), 'Nombre entier');
    });

    test('taille', () {
      expect(heightValidator('178'), isNull);
      expect(heightValidator('850'), 'Entre 100 et 250 cm');
      expect(heightValidator('90'), 'Entre 100 et 250 cm');
    });

    test('poids (décimal, virgule acceptée)', () {
      expect(weightValidator('71,2'), isNull);
      expect(weightValidator('71.2'), isNull);
      expect(weightValidator('693'), 'Entre 25 et 300 kg');
      expect(weightValidator('12'), 'Entre 25 et 300 kg');
    });
  });

  test('parseUserNumber', () {
    expect(parseUserNumber('72,5'), 72.5);
    expect(parseUserNumber('  '), isNull);
    expect(parseUserNumber('abc'), isNull);
  });

  group('filtres de saisie', () {
    test('entier : chiffres seulement, 3 max', () {
      expect(_format(intInput(), '18a2x9'), '182');
    });

    test('décimal : 3 chiffres + 1 décimale max', () {
      expect(_format(decimalInput(), '72,55'), '72,5');
      expect(_format(decimalInput(), '6931'), '693');
      expect(_format(decimalInput(), 'a8b0'), '80');
    });
  });
}
