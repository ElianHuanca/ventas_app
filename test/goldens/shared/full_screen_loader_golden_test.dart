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
}
