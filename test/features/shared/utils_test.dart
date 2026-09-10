import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/changeFormatDate.dart';
import 'package:textiles_app/features/shared/widgets/color_from_hex.dart';

void main() {
  group('colorFromHex', () {
    test('hex de 6 dígitos con #', () {
      expect(colorFromHex('#FF0000'), const Color(0xFFFF0000));
      expect(colorFromHex('#00FF00'), const Color(0xFF00FF00));
    });

    test('hex de 6 dígitos sin #', () {
      expect(colorFromHex('0000FF'), const Color(0xFF0000FF));
    });

    test('hex de 8 dígitos respeta el alpha', () {
      expect(colorFromHex('#80FF0000'), const Color(0x80FF0000));
    });

    test('valor inválido devuelve negro opaco', () {
      expect(colorFromHex('zzzzzz'), const Color(0xFF000000));
      expect(colorFromHex(''), const Color(0xFF000000));
    });

    test('hex de largo inválido cae al negro por defecto', () {
      expect(colorFromHex('#123'), const Color(0xFF000000));
    });

    test('múltiples # se quitan todos', () {
      expect(colorFromHex('##FF0000'), const Color(0xFFFF0000));
    });
  });

  group('changeFormatDate', () {
    test('formatea dia-mes-año', () {
      expect(changeFormatDate(DateTime(2024, 3, 5)), '5-3-2024');
    });

    test('no agrega ceros a la izquierda', () {
      expect(changeFormatDate(DateTime(2024, 12, 25)), '25-12-2024');
      expect(changeFormatDate(DateTime(2024, 1, 1)), '1-1-2024');
    });
  });
}
