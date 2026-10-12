@Tags(['benchmark'])
library;

// Micro-benchmarks de las utilidades puras: formato de fecha, parseo y
// normalización de hex, y traducción de errores de login.
//
// `lib/features/shared/infrastructure/inputs/inputs.dart` está vacío: la
// única validación de formulario pura es `ColorFormCubit.normalizarHex`
// (estática, sin estado).
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/auth/infrastructure/repositories/auth_repository_impl.dart';
import 'package:textiles_app/features/colores/presentation/bloc/color_form_cubit.dart';
import 'package:textiles_app/features/shared/changeFormatDate.dart';
import 'package:textiles_app/features/shared/widgets/color_from_hex.dart';

import 'medicion.dart';

/// Último resultado medido: que el compilador no pueda descartar el trabajo.
Object? sink;

void main() {
  grupoBenchmark('utilidades', () {
    // --- changeFormatDate (títulos y listas de ventas/producciones) ---
    final fecha = DateTime(2026, 10, 11, 14, 30);
    final fechas = [
      for (var i = 0; i < 1000; i++) DateTime(2026, 1 + i % 12, 1 + i % 28)
    ];

    microBenchmark(
      'changeFormatDate x1',
      () => sink = changeFormatDate(fecha),
      presupuestoUs: 2,
      preparar: () => expect(changeFormatDate(fecha), '11-10-2026'),
    );
    microBenchmark(
      'changeFormatDate x1000',
      () => sink = fechas.map(changeFormatDate).toList(),
      presupuestoUs: 3000,
    );

    // --- colorFromHex (avatares de colores en listas y selectores) ---
    microBenchmark(
      'colorFromHex #RRGGBB',
      () => sink = colorFromHex('#FF8800'),
      presupuestoUs: 3,
      preparar: () => expect(colorFromHex('#FF8800'), const Color(0xFFFF8800)),
    );
    microBenchmark(
      'colorFromHex RRGGBB sin #',
      () => sink = colorFromHex('1E88E5'),
      presupuestoUs: 3,
      preparar: () => expect(colorFromHex('1E88E5'), const Color(0xFF1E88E5)),
    );
    microBenchmark(
      'colorFromHex AARRGGBB',
      () => sink = colorFromHex('80FF8800'),
      presupuestoUs: 1.5,
      preparar: () => expect(colorFromHex('80FF8800'), const Color(0x80FF8800)),
    );
    microBenchmark(
      'colorFromHex largo inválido (#ABC)',
      () => sink = colorFromHex('#ABC'),
      presupuestoUs: 1.5,
      preparar: () => expect(colorFromHex('#ABC'), const Color(0xFF000000)),
    );
    microBenchmark(
      'colorFromHex no hex (ZZZZZZ)',
      () => sink = colorFromHex('ZZZZZZ'),
      presupuestoUs: 2,
      preparar: () => expect(colorFromHex('ZZZZZZ'), const Color(0xFF000000)),
    );
    microBenchmark(
      'colorFromHex vacío',
      () => sink = colorFromHex(''),
      presupuestoUs: 0.3,
      preparar: () => expect(colorFromHex(''), const Color(0xFF000000)),
    );
    final hexes = [
      for (var i = 0; i < 1000; i++)
        switch (i % 4) {
          0 => '#${_hex6(i)}',
          1 => _hex6(i),
          2 => '#${_hex6(i).toLowerCase()}',
          _ => '',
        }
    ];
    microBenchmark(
      'colorFromHex x1000 (mezcla de formatos)',
      () => sink = hexes.map(colorFromHex).toList(),
      presupuestoUs: 3000,
    );

    // --- ColorFormCubit.normalizarHex (validación del form de colores) ---
    microBenchmark(
      'ColorFormCubit.normalizarHex válido con #',
      () => sink = ColorFormCubit.normalizarHex('#ff8800'),
      presupuestoUs: 2,
      preparar: () => expect(ColorFormCubit.normalizarHex('#ff8800'), 'FF8800'),
    );
    microBenchmark(
      'ColorFormCubit.normalizarHex con espacios',
      () => sink = ColorFormCubit.normalizarHex('  #1e88e5 '),
      presupuestoUs: 5,
      preparar: () =>
          expect(ColorFormCubit.normalizarHex('  #1e88e5 '), '1E88E5'),
    );
    microBenchmark(
      'ColorFormCubit.normalizarHex largo inválido',
      () => sink = ColorFormCubit.normalizarHex('#FF88001'),
      presupuestoUs: 2,
      preparar: () => expect(ColorFormCubit.normalizarHex('#FF88001'), isNull),
    );
    microBenchmark(
      'ColorFormCubit.normalizarHex no hex',
      () => sink = ColorFormCubit.normalizarHex('GGHHII'),
      presupuestoUs: 1.5,
      preparar: () => expect(ColorFormCubit.normalizarHex('GGHHII'), isNull),
    );

    // --- AuthRepositoryImpl.mensajeDeError (errores de Supabase Auth) ---
    const credenciales = 'Invalid login credentials';
    const sinConfirmar = 'Email not confirmed';
    const limite = 'For security purposes, you can only request this after '
        '60 seconds. Request rate limit reached';
    const desconocido = 'Database error querying schema';
    microBenchmark(
      'AuthRepositoryImpl.mensajeDeError credenciales',
      () => sink = AuthRepositoryImpl.mensajeDeError(credenciales),
      presupuestoUs: 1.5,
      preparar: () => expect(AuthRepositoryImpl.mensajeDeError(credenciales),
          'Email o contraseña incorrectos'),
    );
    microBenchmark(
      'AuthRepositoryImpl.mensajeDeError sin confirmar',
      () => sink = AuthRepositoryImpl.mensajeDeError(sinConfirmar),
      presupuestoUs: 2,
      preparar: () => expect(AuthRepositoryImpl.mensajeDeError(sinConfirmar),
          'El email de esta cuenta no está confirmado'),
    );
    microBenchmark(
      'AuthRepositoryImpl.mensajeDeError rate limit',
      () => sink = AuthRepositoryImpl.mensajeDeError(limite),
      presupuestoUs: 50,
      preparar: () => expect(AuthRepositoryImpl.mensajeDeError(limite),
          'Demasiados intentos. Espera un momento.'),
    );
    microBenchmark(
      'AuthRepositoryImpl.mensajeDeError desconocido',
      () => sink = AuthRepositoryImpl.mensajeDeError(desconocido),
      presupuestoUs: 10,
      preparar: () => expect(AuthRepositoryImpl.mensajeDeError(desconocido),
          'No se pudo iniciar sesión'),
    );
  });
}

/// Hex de 6 dígitos en mayúsculas distinto para cada [i].
String _hex6(int i) => ((i * 2654435761) & 0xFFFFFF)
    .toRadixString(16)
    .padLeft(6, '0')
    .toUpperCase();
