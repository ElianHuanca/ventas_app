import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/colores/presentation/bloc/color_form_cubit.dart';
import 'package:textiles_app/features/shared/widgets/color_from_hex.dart';

import 'vectores.dart';

/// `test/vectores/colores.json` con `colorFromHex` y
/// `ColorFormCubit.normalizarHex`.
void main() {
  probarVectores('colores', (caso) {
    final texto = caso.entrada['texto'] as String;
    switch (caso.entrada['funcion']) {
      case 'colorFromHex':
        expect(
            colorFromHex(texto)
                .toARGB32()
                .toRadixString(16)
                .padLeft(8, '0')
                .toUpperCase(),
            caso.esperado);
      case 'normalizarHex':
        expect(ColorFormCubit.normalizarHex(texto), caso.esperado);
      default:
        fail('función desconocida: ${caso.entrada['funcion']}');
    }
  }, paridad: const {
    // bug: lib/features/shared/widgets/color_from_hex.dart:7 — int.tryParse
    // ignora los espacios alrededor y un hex de 8 caracteres con espacios
    // queda transparente. La spec (colores: "Código guardado inválido") dice
    // negro, y Android da negro
    'colorFromHex: 6 dígitos con dos espacios al final (8 caracteres, no es hex) es negro':
        'paridad: int.tryParse ignora los espacios alrededor: "C0392B  " se lee '
            'como 0x00C0392B y la muestra queda transparente (00C0392B), no negra',
  });
}
