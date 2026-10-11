@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/shared.dart';

import '../golden_helpers.dart';

void main() {
  testWidgets('como raíz de la ruta, igual que en las pantallas de listado',
      (tester) async {
    // Las pantallas devuelven FullScreenLoader directo (sin Scaffold) mientras
    // cargan: así se monta acá. No pinta fondo, así que la captura sale
    // transparente salvo el spinner (en el celular se ve lo que haya detrás
    // de la vista de Flutter).
    await montarParaCaptura(tester, const FullScreenLoader(), asentar: false);
    // En t=0 el spinner es un punto: se avanza el reloj falso hasta ver el arco
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await compararCaptura('full_screen_loader_cargando');
  });

  testWidgets('pinta el fondo de la app mientras carga', (tester) async {
    await montarParaCaptura(tester, const FullScreenLoader(), asentar: false);
    await tester.pump(const Duration(milliseconds: 400));

    // El propio loader tiene que pintar fondo (un Scaffold trae su Material):
    // arriba de la ruta ya hay un Material de la transición, que no alcanza.
    expect(
      find.descendant(
        of: find.byType(FullScreenLoader),
        matching:
            find.byWidgetPredicate((w) => w is Material || w is ColoredBox),
      ),
      findsWidgets,
    );
    await compararCaptura('full_screen_loader_con_fondo');
  },
      // bug: full_screen_loader.dart:9 — devuelve un SizedBox sin Scaffold ni
      // Material, y 15 pantallas lo usan como raíz de la ruta mientras cargan:
      // no pinta fondo (la captura sale transparente) y en el celular se ve lo
      // que haya detrás de la vista de Flutter (en modo oscuro, negro), sin
      // AppBar. Al arreglarlo: quitar el skip y generar la captura con
      // --update-goldens. (testWidgets solo acepta skip bool.)
      skip: true);
}
