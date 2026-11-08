import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/sucursales/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/sucursales/presentation/screens/screens.dart';

import '../../../../helpers/base_falsa.dart';

// Que una sucursal dada de baja no se ofrezca lo decide el filtro
// `activo = true` de SucursalesDatasourceImpl.getSucursales: se prueba con la
// pila de la app (pantalla → SucursalesBloc → repositorio → datasource →
// cliente de Supabase) contra la BaseFalsa.
void main() {
  final base = usarBaseFalsa();

  setUp(() => base.tabla('sucursales', [
        {'id': 1, 'nombre': 'Centro', 'activo': true},
        {'id': 2, 'nombre': 'Norte', 'activo': false},
        {'id': 3, 'nombre': 'Ramada', 'activo': true},
      ]));

  test('getSucursales no trae las dadas de baja', () async {
    final sucursales = await SucursalesDatasourceImpl().getSucursales();

    expect([for (final s in sucursales) s.nombre],
        unorderedEquals(['Centro', 'Ramada']));
  });

  testWidgets(
      'inicio (venta de telas): una sucursal dada de baja no aparece entre '
      'las tarjetas', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Como en lib/main.dart (el SucursalesBloc es global)
    final bloc = SucursalesBloc(
      sucursalesRepository: SucursalesRepositoryImpl(SucursalesDatasourceImpl()),
    );
    addTearDown(bloc.close);
    await tester.pumpWidget(BlocProvider.value(
      value: bloc,
      child: const MaterialApp(home: SucursalesScreen(false)),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(ItemDashboard), findsNWidgets(2));
    expect(find.text('CENTRO'), findsOneWidget);
    expect(find.text('RAMADA'), findsOneWidget);
    expect(find.text('NORTE'), findsNothing);
  });
}
