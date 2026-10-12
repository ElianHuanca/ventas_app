import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/entities/color_item.dart';
import 'package:textiles_app/features/colores/presentation/bloc/color_form_cubit.dart';
import 'package:textiles_app/features/shared/widgets/color_from_hex.dart';

import 'generadores.dart';

/// `colorFromHex` (muestras de color en toda la app) y
/// `ColorFormCubit.normalizarHex` (lo que se guarda en `colores.hex`).
void main() {
  propiedad(
      'un hex de 6 dígitos da el mismo color con o sin #, en '
      'mayúsculas o minúsculas',
      _hexValido, (hex) {
    final esperado = Color(0xFF000000 | int.parse(hex.digitos, radix: 16));

    expect(colorFromHex(hex.texto), esperado);
    expect(colorFromHex(hex.digitos), esperado);
    expect(colorFromHex('#${hex.digitos.toLowerCase()}'), esperado);
  }, casos: 1000);

  propiedad(
      'normalizarHex deja 6 dígitos en mayúsculas sin # (y espacios '
      'alrededor), del mismo color',
      _hexValido, (hex) {
    final normalizado = ColorFormCubit.normalizarHex(hex.conEspacios);

    expect(normalizado, hex.digitos.toUpperCase());
    expect(ColorFormCubit.normalizarHex(normalizado!), normalizado,
        reason: 'idempotente');
    expect(colorFromHex(normalizado), colorFromHex(hex.texto));
  }, casos: 1000);

  propiedad(
      'con cualquier texto ninguna de las dos lanza, y normalizarHex '
      'solo acepta 6 dígitos hexadecimales',
      _textoCualquiera, (texto) {
    final color = colorFromHex(texto);
    final normalizado = ColorFormCubit.normalizarHex(texto);

    expect(color, isA<Color>());
    final sinNumeral = texto.replaceAll('#', '').trim();
    final esHex = RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(sinNumeral);
    expect(normalizado, esHex ? sinNumeral.toUpperCase() : isNull,
        reason: 'normalizarHex("$texto")');
    if (normalizado != null) {
      expect(colorFromHex(normalizado),
          Color(0xFF000000 | int.parse(normalizado, radix: 16)));
    }
  }, casos: 2000);

  propiedad('el formulario guarda el hex normalizado, o no guarda nada',
      _textoCualquiera, (texto) async {
    Map<String, dynamic>? guardado;
    final cubit = ColorFormCubit(
      onCreateCallback: (color) async {
        guardado = color;
        return true;
      },
      onUpdateCallback: (_) async => fail('es un alta'),
      onDeleteCallback: (_) async => fail('es un alta'),
      color: const ColorItem(id: 0, nombre: ''),
    );
    try {
      cubit
        ..onNombreChanged('Rojo')
        ..onHexChanged(texto);

      final ok = await cubit.onSubmit(isUpdate: false);

      final normalizado = ColorFormCubit.normalizarHex(texto);
      expect(ok, normalizado != null);
      expect(guardado?['hex'], normalizado);
    } finally {
      await cubit.close();
    }
  });
}

const _digitosHex = '0123456789abcdef';

class _Hex {
  _Hex(List<int> digitos, List<bool> mayusculas, this.numeral, this.espacios)
      : digitos = [
          for (var i = 0; i < digitos.length; i++)
            mayusculas[i]
                ? _digitosHex[digitos[i]].toUpperCase()
                : _digitosHex[digitos[i]]
        ].join();

  /// 6 dígitos con mayúsculas y minúsculas mezcladas.
  final String digitos;
  final bool numeral;

  /// Espacios/tabs alrededor (como los deja un copiar y pegar).
  final String espacios;

  String get texto => numeral ? '#$digitos' : digitos;
  String get conEspacios => '$espacios$texto$espacios';

  @override
  String toString() => '"$conEspacios"';
}

final _hexValido = any.combine4(
  any.listWithLength(6, any.entero(0, 16)),
  any.listWithLength(6, any.bool),
  any.bool,
  any.choose(['', ' ', '\t', '  ']),
  _Hex.new,
);

/// Caracteres que se parecen a un hex sin serlo: signos que `int.parse`
/// acepta (`+`, `-`), espacios, letras fuera de rango, dígitos y letras de
/// otros alfabetos (`٣`, `Ｆ`) y unos que cambian de largo al pasar a
/// mayúsculas (`ß` → `SS`, `ﬀ` → `FF`).
const _alfabeto = [
  '0', '1', '7', '9', 'a', 'A', 'c', 'f', 'F', 'g', 'G', 'x', 'X', 'z', //
  '#', '+', '-', ' ', '\t', '.', '_', //
  'ß', 'ﬀ', 'é', '٣', 'Ｆ', '😀',
];

/// Textos de 0 a 9 caracteres, con más chances de largo 6-7 (el borde).
final _textoCualquiera = any.combine2(
  any.either(any.entero(0, 10), any.entero(6, 8)),
  any.listWithLength(9, any.entero(0, _alfabeto.length)),
  (int largo, List<int> indices) =>
      indices.take(largo).map((i) => _alfabeto[i]).join(),
);
