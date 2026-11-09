import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/sucursales/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/sucursales/presentation/screens/screens.dart';

import '../../../../helpers/base_falsa.dart';

// Que una sucursal dada de baja no se ofrezca lo decide el filtro
// `activo = true` de SucursalesDatasourceImpl.getSucursales, y el orden de
// las listas lo pide el datasource a PostgREST (postgrest-dart ordena
// descendente si no se le pide `ascending: true`): se prueba con la pila de
// la app (pantalla → bloc/cubit → repositorio → datasource → cliente de
// Supabase) contra la BaseFalsa.
void main() {
  final base = usarBaseFalsa();

  // Desordenadas a propósito: el orden lo tiene que pedir el datasource.
  setUp(() => base.tabla('sucursales', [
        {'id': 3, 'nombre': 'Ramada', 'activo': true},
        {'id': 2, 'nombre': 'Norte', 'activo': false},
        {'id': 1, 'nombre': 'Centro', 'activo': true},
      ]));

  test('getSucursales no trae las dadas de baja', () async {
    final sucursales = await SucursalesDatasourceImpl().getSucursales();

    expect([for (final s in sucursales) s.nombre],
        unorderedEquals(['Centro', 'Ramada']));
  });

  test(
      'getSucursales las trae ordenadas por id ascendente (spec sucursales: '
      '"Listar las sucursales activas")', () async {
    final sucursales = await SucursalesDatasourceImpl().getSucursales();

    expect([for (final s in sucursales) s.id], [1, 3]);
  });

  /// El inicio de la app con el SucursalesBloc global, como en lib/main.dart.
  Future<void> montarInicio(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final bloc = SucursalesBloc(
      sucursalesRepository: SucursalesRepositoryImpl(SucursalesDatasourceImpl()),
    );
    addTearDown(bloc.close);
    await tester.pumpWidget(BlocProvider.value(
      value: bloc,
      child: const MaterialApp(home: SucursalesScreen(false)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'inicio (venta de telas): una sucursal dada de baja no aparece entre '
      'las tarjetas', (tester) async {
    await montarInicio(tester);

    expect(find.byType(ItemDashboard), findsNWidgets(2));
    expect(find.text('CENTRO'), findsOneWidget);
    expect(find.text('RAMADA'), findsOneWidget);
    expect(find.text('NORTE'), findsNothing);
  });

  testWidgets(
      'inicio (venta de telas): las tarjetas van por id, de la sucursal más '
      'vieja a la más nueva', (tester) async {
    await montarInicio(tester);

    expect(
        [
          for (final t in tester.widgetList<ItemDashboard>(
              find.byType(ItemDashboard)))
            t.title,
        ],
        ['Centro', 'Ramada']);
  });

  // Spec sucursales, "Ver qué telas se venden en una sucursal": un
  // interruptor por tela "en el orden por nombre que devuelve la base".
  group('disponibilidad de telas', () {
    // Desordenadas a propósito; Brocado está dada de baja (se lista igual).
    // Nombres que ordenan igual distinga o no mayúsculas la base.
    setUp(() => base
      ..tabla('telas', [
        {'id': 1, 'nombre': 'Seda', 'activo': true},
        {'id': 2, 'nombre': 'Brocado', 'activo': false},
        {'id': 3, 'nombre': 'Lino', 'activo': true},
      ])
      ..tabla('tela_sucursales', [
        {'idtela': 3, 'idsucursal': 1, 'activo': true},
        {'idtela': 1, 'idsucursal': 3, 'activo': true},
      ])
      ..relacion('telas', 'tela_sucursales',
          columna: 'id', referencia: 'idtela'));

    test('getTelasSucursal las trae por nombre, de la A a la Z', () async {
      final telas = await SucursalesDatasourceImpl().getTelasSucursal(1);

      expect([for (final t in telas) (t.nombre, t.disponible)], [
        ('Brocado', false),
        ('Lino', true),
        ('Seda', false),
      ]);
    });

    testWidgets('la pantalla muestra los interruptores en ese orden',
        (tester) async {
      final cubit = SucursalDisponibilidadCubit(
        sucursalesRepository:
            SucursalesRepositoryImpl(SucursalesDatasourceImpl()),
        idsucursal: 1,
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const SucursalDisponibilidadScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(
          [
            for (final s in tester
                .widgetList<SwitchListTile>(find.byType(SwitchListTile)))
              ((s.title! as Text).data, s.value),
          ],
          [('Brocado', false), ('Lino', true), ('Seda', false)]);
    });
  });
}
