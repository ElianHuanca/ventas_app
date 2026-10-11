@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/entities/color_item.dart';
import 'package:textiles_app/features/shared/shared.dart';

import '../golden_helpers.dart';

void main() {
  const colores = [
    ColorItem(id: 1, nombre: 'Blanco', hex: '#FFFFFF', vinculado: true),
    ColorItem(id: 2, nombre: 'Negro', hex: '#000000', vinculado: true),
    ColorItem(id: 3, nombre: 'Rojo carmesí', hex: '#C0392B'),
    ColorItem(id: 4, nombre: 'Azul marino', hex: '#1F3A93', vinculado: true),
    ColorItem(id: 5, nombre: 'Beige', hex: '#E8D8B8'),
    ColorItem(id: 6, nombre: 'Sin hex'),
  ];

  /// Como en TelaColoresScreen: dentro de Screen1 con el nombre de la tela.
  Widget pantalla({required bool isLoading}) => Screen1(
        backRoute: true,
        title: 'Lino',
        isGridview: false,
        widget: [
          ProductoColoresList(
            isLoading: isLoading,
            colores: colores,
            onToggle: (_, __) {},
          ),
        ],
      );

  testWidgets('switches de los colores vinculados y sin vincular',
      (tester) async {
    await montarParaCaptura(tester, pantalla(isLoading: false));

    expect(find.byType(SwitchListTile), findsNWidgets(colores.length));
    await compararCaptura('producto_colores_list_con_colores');
  });

  testWidgets('cargando muestra el indicador en vez de la lista',
      (tester) async {
    await montarParaCaptura(tester, pantalla(isLoading: true), asentar: false);
    // En t=0 el spinner es un punto: se avanza el reloj falso hasta ver el arco
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SwitchListTile), findsNothing);
    await compararCaptura('producto_colores_list_cargando');
  });
}
