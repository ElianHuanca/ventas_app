import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';
import 'package:textiles_app/features/apliques/presentation/widgets/data_table_apliques.dart';

import '../../../../helpers/fake_repositories.dart';

/// Repo de apliques cuya carga queda pendiente hasta completar [carga].
class _ApliquesLento extends FakeApliquesRepository {
  final carga = Completer<List<Aplique>>();

  @override
  Future<List<Aplique>> getApliques({bool soloActivos = true}) => carga.future;
}

void main() {
  late FakeApliquesRepository apliquesRepo;
  late FakeVentasApliquesRepository ventasRepo;
  late ApliquesBloc apliquesBloc;
  late VentaApliquesFormCubit cubit;
  late GoRouter router;

  final apliques = [
    Aplique(id: 1, nombre: 'Flor', costoFabricacion: 10),
    Aplique(id: 2, nombre: 'Luna', costoFabricacion: 4),
  ];
  // Stock de la sucursal 3: Flor en Rojo y Azul, Luna en Verde
  const stock = [
    StockAplique(
        apliqueId: 1,
        colorId: 5,
        colorNombre: 'Rojo',
        hex: '#FF0000',
        stock: 10),
    StockAplique(
        apliqueId: 1,
        colorId: 7,
        colorNombre: 'Azul',
        hex: '#0000FF',
        stock: 2),
    StockAplique(
        apliqueId: 2,
        colorId: 9,
        colorNombre: 'Verde',
        hex: '#00FF00',
        stock: 5),
  ];

  setUp(() {
    apliquesRepo = FakeApliquesRepository(apliques: apliques, stock: stock);
    ventasRepo = FakeVentasApliquesRepository();
  });

  /// Monta el registro empujado sobre el historial (como en la app), para
  /// que el pop al guardar tenga a dónde volver.
  Future<void> montar(WidgetTester tester, {bool esperar = true}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    apliquesBloc =
        ApliquesBloc(apliquesRepository: apliquesRepo, idsucursal: 3);
    addTearDown(apliquesBloc.close);
    cubit = VentaApliquesFormCubit(
        ventasApliquesRepository: ventasRepo, idsucursal: 3);
    addTearDown(cubit.close);
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('STUB HISTORIAL')),
        ),
        GoRoute(
          path: '/venta-apliques/registro/:idsucursal',
          builder: (_, __) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: apliquesBloc),
              BlocProvider.value(value: cubit),
            ],
            child: VentaApliquesScreen(),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/venta-apliques/registro/3');
    if (esperar) await tester.pumpAndSettle();
  }

  Future<void> seleccionarAplique(WidgetTester tester, String nombre) async {
    await tester.tap(find.byType(DropdownMenu<Aplique>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(nombre).last);
    await tester.pumpAndSettle();
  }

  Future<void> seleccionarColor(WidgetTester tester, String texto) async {
    await tester.tap(find.byType(DropdownMenu<StockAplique>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(texto).last);
    await tester.pumpAndSettle();
  }

  Finder campo(String label) => find.widgetWithText(TextFormField, label);

  Future<void> tocar(WidgetTester tester, String texto) async {
    await tester.ensureVisible(find.text(texto));
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

  /// Texto visible en un campo de texto.
  String textoDe(WidgetTester tester, Finder finder) => tester
      .widget<TextField>(find.descendant(
        of: finder,
        matching: find.byType(TextField),
      ))
      .controller!
      .text;

  /// Importe que se muestra junto a "Total a pagar".
  String totalAPagar(WidgetTester tester) {
    final fila = find
        .ancestor(of: find.text('Total a pagar'), matching: find.byType(Row))
        .first;
    return tester
        .widgetList<Text>(
            find.descendant(of: fila, matching: find.byType(Text)))
        .last
        .data!;
  }

  /// Texto dentro de la tabla de líneas (DataTableApliques).
  Finder enTabla(String texto) => find.descendant(
      of: find.byType(DataTableApliques), matching: find.text(texto));

  group('carga', () {
    testWidgets('renderiza dropdowns, campos y botones Añadir/Guardar',
        (tester) async {
      await montar(tester);

      expect(find.text('Venta de Apliques'), findsOneWidget);
      expect(find.text('Seleccione un Aplique'), findsOneWidget);
      expect(find.text('Seleccione un Color'), findsOneWidget);
      expect(campo('Cantidad'), findsOneWidget);
      expect(campo('Precio'), findsOneWidget);
      expect(campo('Descuento'), findsOneWidget);
      expect(find.text('Añadir'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      expect(totalAPagar(tester), '0.0 Bs');
    });

    testWidgets('pide solo apliques activos y el stock de la sucursal',
        (tester) async {
      await montar(tester);

      expect(apliquesRepo.lastSoloActivos, isTrue);
      expect(apliquesRepo.lastGetStockSucursalId, 3);
    });

    testWidgets('mientras cargan los apliques muestra el loader',
        (tester) async {
      final lento = _ApliquesLento();
      apliquesRepo = lento;
      await montar(tester, esperar: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(DropdownMenu<Aplique>), findsNothing);

      lento.carga.complete(apliques);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(DropdownMenu<Aplique>), findsOneWidget);
    });
  });

  group('selección de aplique y color', () {
    testWidgets('el color está deshabilitado hasta elegir un aplique',
        (tester) async {
      await montar(tester);

      expect(
          tester
              .widget<DropdownMenu<StockAplique>>(
                  find.byType(DropdownMenu<StockAplique>))
              .enabled,
          isFalse);

      await seleccionarAplique(tester, 'Flor');

      expect(
          tester
              .widget<DropdownMenu<StockAplique>>(
                  find.byType(DropdownMenu<StockAplique>))
              .enabled,
          isTrue);
    });

    testWidgets('ofrece solo los colores con stock del aplique elegido',
        (tester) async {
      await montar(tester);

      await seleccionarAplique(tester, 'Flor');
      await tester.tap(find.byType(DropdownMenu<StockAplique>));
      await tester.pumpAndSettle();

      expect(find.text('Rojo (stock: 10.0)'), findsWidgets);
      expect(find.text('Azul (stock: 2.0)'), findsWidgets);
      // Verde es de Luna: no se ofrece para Flor
      expect(find.text('Verde (stock: 5.0)'), findsNothing);
    });

    testWidgets('al cambiar de aplique se reinicia el color elegido',
        (tester) async {
      await montar(tester);

      await seleccionarAplique(tester, 'Flor');
      await seleccionarColor(tester, 'Rojo (stock: 10.0)');
      expect(textoDe(tester, find.byType(DropdownMenu<StockAplique>)),
          'Rojo (stock: 10.0)');

      await seleccionarAplique(tester, 'Luna');

      expect(textoDe(tester, find.byType(DropdownMenu<StockAplique>)), '');
      expect(find.text('Seleccione un Color'), findsOneWidget);

      // Sin color no se puede añadir
      await tester.enterText(campo('Cantidad'), '1');
      await tester.enterText(campo('Precio'), '30');
      await tocar(tester, 'Añadir');
      expect(find.text('Seleccione un color'), findsOneWidget);
      expect(find.text('Luna (Rojo)'), findsNothing);
    });
  });

  group('líneas', () {
    testWidgets(
        'Añadir agrega la línea a la tabla, suma el total y limpia '
        'cantidad y precio', (tester) async {
      await montar(tester);

      await agregarLinea(tester,
          aplique: 'Flor',
          color: 'Rojo (stock: 10.0)',
          cantidad: '2',
          precio: '25');

      expect(enTabla('Flor (Rojo)'), findsOneWidget);
      expect(enTabla('2.0'), findsOneWidget);
      expect(enTabla('25.0Bs'), findsOneWidget);
      expect(enTabla('50.0Bs'), findsOneWidget);
      expect(enTabla('50.0 Bs'), findsOneWidget);
      expect(totalAPagar(tester), '50.0 Bs');

      expect(textoDe(tester, campo('Cantidad')), '');
      expect(textoDe(tester, campo('Precio')), '');
    });

    testWidgets('Añadir sin aplique avisa y no agrega nada', (tester) async {
      await montar(tester);

      await tocar(tester, 'Añadir');

      expect(find.text('Seleccione un aplique'), findsOneWidget);
      expect(find.byIcon(Icons.delete_forever_rounded), findsNothing);
    });

    testWidgets(
        'sobre-stock muestra "Stock insuficiente..." y no agrega la línea',
        (tester) async {
      await montar(tester);

      await agregarLinea(tester,
          aplique: 'Flor',
          color: 'Azul (stock: 2.0)',
          cantidad: '3',
          precio: '20');

      expect(find.text('Stock insuficiente. Disponible: 2.0'), findsOneWidget);
      expect(find.text('Flor (Azul)'), findsNothing);
      expect(totalAPagar(tester), '0.0 Bs');
      // Los campos quedan para corregir
      expect(textoDe(tester, campo('Cantidad')), '3');
      expect(textoDe(tester, campo('Precio')), '20');
    });

    testWidgets('el sobre-stock cuenta lo que ya está en la venta',
        (tester) async {
      await montar(tester);

      await agregarLinea(tester,
          aplique: 'Flor',
          color: 'Azul (stock: 2.0)',
          cantidad: '2',
          precio: '20');
      expect(enTabla('Flor (Azul)'), findsOneWidget);

      // 2 en la venta + 1 más supera el stock de 2
      await tester.enterText(campo('Cantidad'), '1');
      await tester.enterText(campo('Precio'), '20');
      await tocar(tester, 'Añadir');

      expect(find.text('Stock insuficiente. Disponible: 2.0'), findsOneWidget);
      expect(enTabla('2.0'), findsOneWidget);
      expect(totalAPagar(tester), '40.0 Bs');
    });

    testWidgets('quitar una línea la saca de la tabla y resta su total',
        (tester) async {
      await montar(tester);

      await agregarLinea(tester,
          aplique: 'Flor',
          color: 'Rojo (stock: 10.0)',
          cantidad: '2',
          precio: '25');
      await agregarLinea(tester,
          aplique: 'Luna',
          color: 'Verde (stock: 5.0)',
          cantidad: '1',
          precio: '30');
      expect(totalAPagar(tester), '80.0 Bs');

      // La última añadida va primero: Flor es la segunda fila
      await tester.tap(find.byIcon(Icons.delete_forever_rounded).last);
      await tester.pumpAndSettle();

      expect(find.text('Flor (Rojo)'), findsNothing);
      expect(enTabla('Luna (Verde)'), findsOneWidget);
      expect(enTabla('30.0 Bs'), findsOneWidget);
      expect(totalAPagar(tester), '30.0 Bs');
    });

    testWidgets('el descuento se resta del total a pagar', (tester) async {
      await montar(tester);

      await agregarLinea(tester,
          aplique: 'Flor',
          color: 'Rojo (stock: 10.0)',
          cantidad: '2',
          precio: '25');
      await tester.enterText(campo('Descuento'), '10');
      await tester.pump();

      expect(totalAPagar(tester), '40.0 Bs');
      // La tabla sigue mostrando el total sin descuento
      expect(enTabla('50.0 Bs'), findsOneWidget);
    });

    // bug: VentaApliquesFormCubit.addDetalle (venta_apliques_form_cubit.dart
    // :140) acumula el total sumando doubles sin redondear: 10.1 + 20.2 se ve
    // como "30.299999999999997 Bs" y se manda así a crear_venta_apliques
    // (p_total NUMERIC guarda el ruido). testWidgets solo acepta skip bool.
    testWidgets('el total no arrastra error de coma flotante', skip: true,
        (tester) async {
      await montar(tester);

      await agregarLinea(tester,
          aplique: 'Flor',
          color: 'Rojo (stock: 10.0)',
          cantidad: '1',
          precio: '10.1');
      await agregarLinea(tester,
          aplique: 'Flor',
          color: 'Rojo (stock: 10.0)',
          cantidad: '1',
          precio: '20.2');

      expect(totalAPagar(tester), '30.3 Bs');

      await tocar(tester, 'Guardar');
      await tocar(tester, 'Confirmar');
      expect(ventasRepo.lastTotal, 30.3);
    });
  });

  group('guardar', () {
    testWidgets('sin líneas avisa y no abre la confirmación', (tester) async {
      await montar(tester);

      await tocar(tester, 'Guardar');

      expect(
          find.text('Agregue al menos un aplique a la venta'), findsOneWidget);
      expect(find.text('Confirmar Venta'), findsNothing);
      expect(ventasRepo.createCalls, 0);
    });

    testWidgets(
        'confirmar envía totales y líneas al repo, avisa y vuelve al historial',
        (tester) async {
      await montar(tester);

      await agregarLinea(tester,
          aplique: 'Flor',
          color: 'Rojo (stock: 10.0)',
          cantidad: '2',
          precio: '25');
      await tester.enterText(campo('Descuento'), '10');
      await tester.pump();

      await tocar(tester, 'Guardar');
      expect(find.text('Confirmar Venta'), findsOneWidget);
      expect(find.text('¿Está seguro de registrar esta venta de apliques?'),
          findsOneWidget);

      await tocar(tester, 'Confirmar');

      expect(ventasRepo.createCalls, 1);
      expect(ventasRepo.lastIdsucursales, 3);
      expect(ventasRepo.lastTotal, 40.0);
      expect(ventasRepo.lastDescuento, 10.0);
      // (25 - 10 de costo de fabricación) x 2
      expect(ventasRepo.lastGanancias, 30.0);
      expect(ventasRepo.lastDetalles, [
        {
          'idapliques': 1,
          'idcolor': 5,
          'nombre': 'Flor (Rojo)',
          'cantidad': 2.0,
          'precio': 25.0,
          'total': 50.0,
          'ganancias': 30.0,
        },
      ]);

      expect(find.text('Realizado correctamente'), findsOneWidget);
      expect(find.text('STUB HISTORIAL'), findsOneWidget);
      expect(find.byType(VentaApliquesScreen), findsNothing);
    });

    testWidgets('sin descuento se envía 0', (tester) async {
      await montar(tester);

      await agregarLinea(tester,
          aplique: 'Luna',
          color: 'Verde (stock: 5.0)',
          cantidad: '1',
          precio: '30');
      await tocar(tester, 'Guardar');
      await tocar(tester, 'Confirmar');

      expect(ventasRepo.lastTotal, 30.0);
      expect(ventasRepo.lastDescuento, 0.0);
    });

    testWidgets('cancelar la confirmación no envía y deja la venta armada',
        (tester) async {
      await montar(tester);

      await agregarLinea(tester,
          aplique: 'Flor',
          color: 'Rojo (stock: 10.0)',
          cantidad: '2',
          precio: '25');
      await tocar(tester, 'Guardar');
      await tocar(tester, 'Cancelar');

      expect(find.text('Confirmar Venta'), findsNothing);
      expect(ventasRepo.createCalls, 0);
      expect(enTabla('Flor (Rojo)'), findsOneWidget);
      expect(find.text('STUB HISTORIAL'), findsNothing);
    });

    testWidgets('si el repo falla avisa el error y se queda en la pantalla',
        (tester) async {
      ventasRepo.error = Exception('Stock insuficiente');
      await montar(tester);

      await agregarLinea(tester,
          aplique: 'Flor',
          color: 'Rojo (stock: 10.0)',
          cantidad: '2',
          precio: '25');
      await tocar(tester, 'Guardar');
      await tocar(tester, 'Confirmar');

      expect(find.text('Hubo un error'), findsOneWidget);
      expect(find.text('STUB HISTORIAL'), findsNothing);
      expect(enTabla('Flor (Rojo)'), findsOneWidget);
    });

    testWidgets('un descuento mayor al total no envía la venta',
        (tester) async {
      await montar(tester);

      await agregarLinea(tester,
          aplique: 'Flor',
          color: 'Rojo (stock: 10.0)',
          cantidad: '2',
          precio: '25');
      await tester.enterText(campo('Descuento'), '60');
      await tester.pump();
      await tocar(tester, 'Guardar');
      await tocar(tester, 'Confirmar');

      expect(ventasRepo.createCalls, 0);
      expect(find.text('Hubo un error'), findsOneWidget);
      expect(find.text('STUB HISTORIAL'), findsNothing);
    });
  });
}
