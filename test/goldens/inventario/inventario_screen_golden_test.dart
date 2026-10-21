@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

/// Repo cuyo inventario queda pendiente hasta completar [espera].
class _RepoLento extends FakeApliquesRepository {
  final espera = Completer<void>();

  _RepoLento({super.inventarioConVentas});

  @override
  Future<List<StockConVentas>> getInventarioConVentas(
    int sucursalId, {
    required DateTime desde,
    required DateTime hasta,
  }) async {
    await espera.future;
    return super.getInventarioConVentas(sucursalId, desde: desde, hasta: hasta);
  }
}

const _bolsaGrande = 'Flor Petalo Suizo Grande - Bolsa x100 und';
const _bolsaMediana = 'Flor Petalo Suizo Mediana - Bolsa x100 und';
const _mariposa = 'Mariposa Lentejuela 8x6 - Bolsa x50 und';
const _corazon = 'Corazón Raso 5x5 - Bolsa x100 und';
const _estrella = 'Estrella Dorada 4x4 - Bolsa x100 und';

/// Ramada: poco stock de lo que más se vende y algunos sin ventas.
/// Con la regla (mínimo = vendidas × 2,5 / 4; se pide hasta el doble):
/// Rojo hacer 48, Blanco 25, Negro 13, Rosado 12, Dorado mediana 12 → 110.
const _ramada = [
  StockConVentas(
      apliqueId: 1,
      aplique: _bolsaGrande,
      colorId: 1,
      color: 'Rojo',
      hex: '#C62828',
      stock: 2,
      vendidas: 40),
  StockConVentas(
      apliqueId: 1,
      aplique: _bolsaGrande,
      colorId: 2,
      color: 'Blanco',
      hex: '#FFFFFF',
      stock: 5,
      vendidas: 24),
  StockConVentas(
      apliqueId: 1,
      aplique: _bolsaGrande,
      colorId: 3,
      color: 'Rosado',
      hex: '#F48FB1',
      stock: 0,
      vendidas: 9),
  StockConVentas(
      apliqueId: 1,
      aplique: _bolsaGrande,
      colorId: 4,
      color: 'Celeste',
      hex: '#81D4FA',
      stock: 12,
      vendidas: 0),
  StockConVentas(
      apliqueId: 2,
      aplique: _bolsaMediana,
      colorId: 5,
      color: 'Dorado',
      hex: '#D4AF37',
      stock: 8,
      vendidas: 16),
  StockConVentas(
      apliqueId: 3,
      aplique: _mariposa,
      colorId: 6,
      color: 'Negro',
      hex: '#212121',
      stock: 3,
      vendidas: 12),
  StockConVentas(
      apliqueId: 4,
      aplique: _corazon,
      colorId: 1,
      color: 'Rojo',
      hex: '#C62828',
      stock: 60,
      vendidas: 8),
  StockConVentas(
      apliqueId: 5,
      aplique: _estrella,
      colorId: 5,
      color: 'Dorado',
      hex: '#D4AF37',
      stock: 30,
      vendidas: 0),
];

/// Sucursal nueva: no vendió nada en la ventana, se estima con las otras.
const _sinHistorial = [
  StockConVentas(
      apliqueId: 1,
      aplique: _bolsaGrande,
      colorId: 1,
      color: 'Rojo',
      hex: '#C62828',
      stock: 4,
      vendidas: 0,
      vendidasOtras: 28),
  StockConVentas(
      apliqueId: 1,
      aplique: _bolsaGrande,
      colorId: 2,
      color: 'Blanco',
      hex: '#FFFFFF',
      stock: 10,
      vendidas: 0,
      vendidasOtras: 12),
  StockConVentas(
      apliqueId: 3,
      aplique: _mariposa,
      colorId: 6,
      color: 'Negro',
      hex: '#212121',
      stock: 20,
      vendidas: 0,
      vendidasOtras: 6),
];

/// Todo con stock de sobra para lo que se vende.
const _completo = [
  StockConVentas(
      apliqueId: 1,
      aplique: _bolsaGrande,
      colorId: 1,
      color: 'Rojo',
      hex: '#C62828',
      stock: 90,
      vendidas: 40),
  StockConVentas(
      apliqueId: 1,
      aplique: _bolsaGrande,
      colorId: 2,
      color: 'Blanco',
      hex: '#FFFFFF',
      stock: 45,
      vendidas: 24),
  StockConVentas(
      apliqueId: 4,
      aplique: _corazon,
      colorId: 1,
      color: 'Rojo',
      hex: '#C62828',
      stock: 60,
      vendidas: 8),
];

void main() {
  /// Las ventas se miran hasta hoy: se fija para que la captura no cambie.
  DateTime hoy() => DateTime(2026, 10, 15);

  /// El SucursalesBloc es global en la app (main.dart): de ahí sale el nombre
  /// de la sucursal del título.
  Future<void> montar(
    WidgetTester tester,
    FakeApliquesRepository repo, {
    int idsucursal = 1,
    bool asentar = true,
  }) async {
    final sucursales = SucursalesBloc(
      sucursalesRepository: FakeSucursalesRepository(sucursales: [
        Sucursal(id: 1, nombre: 'Ramada'),
        Sucursal(id: 2, nombre: 'Shopping Miami Feria Barrio Lindo'),
      ]),
    );
    addTearDown(sucursales.close);
    final cubit = InventarioCubit(
      apliquesRepository: repo,
      idsucursal: idsucursal,
      hoy: hoy,
    );
    addTearDown(cubit.close);
    await montarParaCaptura(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: sucursales),
          BlocProvider.value(value: cubit),
        ],
        child: InventarioScreen(idsucursal: idsucursal),
      ),
      asentar: asentar,
    );
  }

  testWidgets('faltantes: el más urgente primero y cuánto hacer',
      (tester) async {
    await montar(tester, FakeApliquesRepository(inventarioConVentas: _ramada));

    await compararCaptura('inventario_screen_faltantes');
  });

  testWidgets('todos: también lo que alcanza y lo que no se vende',
      (tester) async {
    await montar(tester, FakeApliquesRepository(inventarioConVentas: _ramada));
    await tester.tap(find.textContaining('Todos').hitTestable());
    await tester.pumpAndSettle();

    await compararCaptura('inventario_screen_todos');
  });

  testWidgets('todos, al final: sin "Hacer" en lo que alcanza o no se vende',
      (tester) async {
    await montar(tester, FakeApliquesRepository(inventarioConVentas: _ramada));
    await tester.tap(find.textContaining('Todos').hitTestable());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('se pide hasta cubrir el doble'),
      300,
    );
    await tester.pumpAndSettle();

    await compararCaptura('inventario_screen_todos_final');
  });

  testWidgets('estimada: la sucursal no vendió nada, se usa la de las otras',
      (tester) async {
    await montar(
      tester,
      FakeApliquesRepository(inventarioConVentas: _sinHistorial),
      idsucursal: 2,
    );

    await compararCaptura('inventario_screen_estimada');
  });

  testWidgets('no falta nada', (tester) async {
    await montar(
        tester, FakeApliquesRepository(inventarioConVentas: _completo));

    await compararCaptura('inventario_screen_no_falta_nada');
  });

  testWidgets('sin inventario', (tester) async {
    await montar(tester, FakeApliquesRepository());

    await compararCaptura('inventario_screen_vacio');
  });

  testWidgets('sin conexión: avisa del error y ofrece reintentar',
      (tester) async {
    await montar(
      tester,
      FakeApliquesRepository(inventarioConVentas: _ramada)
        ..error = Exception('Sin conexión'),
    );

    await compararCaptura('inventario_screen_error');
  });

  testWidgets('cargando', (tester) async {
    final lento = _RepoLento(inventarioConVentas: _ramada);
    await montar(tester, lento, asentar: false);
    // En el instante 0 el arco del spinner mide 0: se avanza un tramo fijo
    // (el tiempo es falso, así que la captura es fija).
    await tester.pump(const Duration(milliseconds: 400));

    // Se libera la carga aunque la captura falle: si no, el cubit emitiría
    // después de cerrado.
    try {
      await compararCaptura('inventario_screen_cargando');
    } finally {
      lento.espera.complete();
    }
    await tester.pumpAndSettle();
  });
}
