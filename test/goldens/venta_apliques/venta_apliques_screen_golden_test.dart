@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

/// Repo de apliques cuya carga queda pendiente hasta completar [carga].
class _ApliquesLento extends FakeApliquesRepository {
  final carga = Completer<List<Aplique>>();

  @override
  Future<List<Aplique>> getApliques({bool soloActivos = true}) => carga.future;
}

void main() {
  final apliques = [
    Aplique(id: 1, nombre: 'Flor bordada 10x10', costoFabricacion: 12),
    Aplique(id: 2, nombre: 'Corazón 5x5', costoFabricacion: 3),
    Aplique(id: 3, nombre: 'Mariposa 8x6', costoFabricacion: 7),
  ];
  // Stock de la sucursal por aplique+color (solo colores vinculados)
  const stock = [
    StockAplique(
        apliqueId: 1,
        colorId: 5,
        colorNombre: 'Rojo',
        hex: '#D32F2F',
        stock: 12),
    StockAplique(
        apliqueId: 1,
        colorId: 8,
        colorNombre: 'Azul marino',
        hex: '#1A237E',
        stock: 2),
    StockAplique(
        apliqueId: 1,
        colorId: 11,
        colorNombre: 'Blanco',
        hex: '#FFFFFF',
        stock: 7),
    StockAplique(
        apliqueId: 2,
        colorId: 5,
        colorNombre: 'Rojo',
        hex: '#D32F2F',
        stock: 30),
    StockAplique(
        apliqueId: 2,
        colorId: 9,
        colorNombre: 'Rosado',
        hex: '#F48FB1',
        stock: 15),
    StockAplique(
        apliqueId: 3,
        colorId: 12,
        colorNombre: 'Dorado',
        hex: '#C9A227',
        stock: 4),
  ];

  Future<void> montar(
    WidgetTester tester, {
    FakeApliquesRepository? apliquesRepo,
    bool asentar = true,
  }) async {
    final apliquesBloc = ApliquesBloc(
      apliquesRepository: apliquesRepo ??
          FakeApliquesRepository(apliques: apliques, stock: stock),
      idsucursal: 1,
    );
    addTearDown(apliquesBloc.close);
    final cubit = VentaApliquesFormCubit(
      ventasApliquesRepository: FakeVentasApliquesRepository(),
      idsucursal: 1,
    );
    addTearDown(cubit.close);
    await montarParaCaptura(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: apliquesBloc),
          BlocProvider.value(value: cubit),
        ],
        child: VentaApliquesScreen(),
      ),
      asentar: asentar,
    );
  }

  Future<void> seleccionarAplique(WidgetTester tester, String nombre) async {
    await tester.tap(find.byType(DropdownMenu<Aplique>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(nombre).last);
    await tester.pumpAndSettle();
  }

  Future<void> abrirColores(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownMenu<StockAplique>));
    await tester.pumpAndSettle();
  }

  Future<void> seleccionarColor(WidgetTester tester, String texto) async {
    await abrirColores(tester);
    await tester.tap(find.text(texto).last);
    await tester.pumpAndSettle();
  }

  Finder campo(String label) => find.widgetWithText(TextFormField, label);

  Future<void> tocar(WidgetTester tester, String texto) async {
    await tester.ensureVisible(find.text(texto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(texto));
    await tester.pumpAndSettle();
  }

  Future<void> agregarLinea(
    WidgetTester tester, {
    required String aplique,
    required String color,
    required String cantidad,
    required String precio,
  }) async {
    await seleccionarAplique(tester, aplique);
    await seleccionarColor(tester, color);
    await tester.enterText(campo('Cantidad'), cantidad);
    await tester.enterText(campo('Precio'), precio);
    await tocar(tester, 'Añadir');
  }

  /// Arma una venta de tres líneas (173 Bs).
  Future<void> armarVenta(WidgetTester tester) async {
    await agregarLinea(tester,
        aplique: 'Flor bordada 10x10',
        color: 'Rojo (stock: 12.0)',
        cantidad: '3',
        precio: '25');
    await agregarLinea(tester,
        aplique: 'Corazón 5x5',
        color: 'Rosado (stock: 15.0)',
        cantidad: '6',
        precio: '8');
    await agregarLinea(tester,
        aplique: 'Flor bordada 10x10',
        color: 'Azul marino (stock: 2.0)',
        cantidad: '2',
        precio: '25');
  }

  /// Saca el foco del campo de texto (sin cursor en la captura) y vuelve
  /// arriba de todo.
  Future<void> soltarFocoYSubir(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(DropdownMenu<Aplique>));
    await tester.pumpAndSettle();
  }

  testWidgets('formulario vacío', (tester) async {
    await montar(tester);

    await compararCaptura('venta_apliques_vacia');
  });

  testWidgets('cargando los apliques', (tester) async {
    final lento = _ApliquesLento();
    await montar(tester, apliquesRepo: lento, asentar: false);
    // Avanza el reloj de prueba para que el arco del loader se vea (en t=0
    // es un punto); el tiempo es falso, así que la captura es fija.
    await tester.pump(const Duration(milliseconds: 400));

    // Se libera la carga aunque la captura falle: si no, el close() del
    // bloc espera ese handler y el test se cuelga hasta el timeout.
    try {
      await compararCaptura('venta_apliques_cargando');
    } finally {
      lento.carga.complete(apliques);
    }
    await tester.pumpAndSettle();
  });

  testWidgets('colores del aplique con su stock', (tester) async {
    await montar(tester);
    await seleccionarAplique(tester, 'Flor bordada 10x10');

    await abrirColores(tester);

    await compararCaptura('venta_apliques_colores_con_stock');
  });

  testWidgets('líneas en el carrito', (tester) async {
    await montar(tester);
    await armarVenta(tester);
    await soltarFocoYSubir(tester);

    await compararCaptura('venta_apliques_con_lineas');
  });

  testWidgets('sobre-stock: avisa el stock disponible y no agrega la línea',
      (tester) async {
    await montar(tester);
    await agregarLinea(tester,
        aplique: 'Flor bordada 10x10',
        color: 'Rojo (stock: 12.0)',
        cantidad: '3',
        precio: '25');

    // Azul marino tiene 2 en stock: pedir 3 no entra
    await agregarLinea(tester,
        aplique: 'Flor bordada 10x10',
        color: 'Azul marino (stock: 2.0)',
        cantidad: '3',
        precio: '25');
    expect(find.text('Stock insuficiente. Disponible: 2.0'), findsOneWidget);
    await soltarFocoYSubir(tester);

    await compararCaptura('venta_apliques_sobre_stock');
  });

  testWidgets('descuento restado del total a pagar', (tester) async {
    await montar(tester);
    await armarVenta(tester);
    await tester.enterText(campo('Descuento'), '13');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar'));
    await tester.pumpAndSettle();

    await compararCaptura('venta_apliques_con_descuento');
  });

  testWidgets('confirmación antes de guardar', (tester) async {
    await montar(tester);
    await armarVenta(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tocar(tester, 'Guardar');

    await compararCaptura('venta_apliques_confirmar');
  });
}
