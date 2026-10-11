@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/ventas/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

/// Como `tela_sucursales`: cada sucursal ofrece solo las telas vinculadas.
class _TelasPorSucursalRepo extends FakeTelasRepository {
  _TelasPorSucursalRepo({super.telas, required this.porSucursal});

  final Map<int, List<int>> porSucursal;

  @override
  Future<List<Tela>> getTelasPorSucursal(int idsucursal) async {
    final todas = await super.getTelasPorSucursal(idsucursal);
    final ids = porSucursal[idsucursal] ?? const [];
    return todas.where((t) => ids.contains(t.id)).toList();
  }
}

void main() {
  final telas = [
    Tela(id: 1, nombre: 'Lino', precxmen: 35, precxcompra: 22),
    Tela(id: 2, nombre: 'Seda', precxmen: 60, precxcompra: 40),
    Tela(id: 3, nombre: 'Gabardina', precxmen: 28, precxcompra: 18),
    Tela(id: 4, nombre: 'Lino Rústico', precxmen: 32, precxcompra: 20),
  ];

  late DetalleVentaFormCubit cubit;

  /// Monta el registro de la sucursal 1 ("Central", que no vende Seda) con
  /// la fecha fijada en el cubit (por defecto sería la de hoy).
  Future<void> montar(WidgetTester tester) async {
    final telasRepo = _TelasPorSucursalRepo(
      telas: telas,
      porSucursal: {
        1: [1, 3, 4],
        2: [1, 2],
      },
    );
    cubit = DetalleVentaFormCubit(
      ventasRepository: FakeVentasRepository(),
      detalleVentasRepository: FakeDetalleVentasRepository(),
      idsucursal: 1,
    )..onFechaChanged(DateTime(2026, 10, 10));
    final telasBloc = TelasBloc(telasRepository: telasRepo, idsucursal: 1);
    addTearDown(cubit.close);
    addTearDown(telasBloc.close);
    await montarParaCaptura(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(value: telasBloc),
        ],
        child: DetVenta(),
      ),
    );
  }

  Finder campo(String label) => find.widgetWithText(TextFormField, label);

  Future<void> desenfocar(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  /// Elige la opción del menú (no el texto de la tabla del carrito, que
  /// también puede decir [nombre]).
  Future<void> elegirTela(WidgetTester tester, String nombre) async {
    await tester.tap(find.byType(DropdownMenu<Tela>));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, nombre).last);
    await tester.pumpAndSettle();
  }

  Future<void> anadirLinea(
    WidgetTester tester, {
    required String tela,
    required String precio,
    required String cantidad,
  }) async {
    await elegirTela(tester, tela);
    await tester.enterText(campo('Precio'), precio);
    await tester.enterText(campo('Cantidad'), cantidad);
    await tester.tap(find.text('Añadir'));
    await tester.pumpAndSettle();
  }

  /// Lino a 35 Bs dos veces (se acumula en una línea de 3.5 mts) y
  /// Gabardina a 24.5 Bs.
  Future<void> llenarCarrito(WidgetTester tester) async {
    await anadirLinea(tester, tela: 'Lino', precio: '35', cantidad: '2');
    await anadirLinea(tester,
        tela: 'Gabardina', precio: '24.5', cantidad: '10');
    await anadirLinea(tester, tela: 'Lino', precio: '35', cantidad: '1.5');
    await desenfocar(tester);
  }

  testWidgets('formulario vacío', (tester) async {
    await montar(tester);

    await compararCaptura('det_venta_vacio');
  });

  testWidgets('selector con las telas de la sucursal', (tester) async {
    await montar(tester);

    await tester.tap(find.byType(DropdownMenu<Tela>));
    await tester.pumpAndSettle();

    await compararCaptura('det_venta_selector_telas');
  });

  testWidgets('carrito con líneas acumuladas', (tester) async {
    await montar(tester);
    await llenarCarrito(tester);

    expect(cubit.state.detVentas, hasLength(2));
    await compararCaptura('det_venta_carrito');
  });

  testWidgets('carrito con descuento', (tester) async {
    await montar(tester);
    await llenarCarrito(tester);
    await tester.enterText(campo('Descuento'), '15');
    await desenfocar(tester);

    await compararCaptura('det_venta_descuento');
  });

  testWidgets('error al guardar sin líneas', (tester) async {
    await montar(tester);

    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Hubo un error'), findsOneWidget);
    await compararCaptura('det_venta_error_sin_lineas');
  });
}
