import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/sucursales/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

/// `/`, `/sucursales`, `/sucursal/:id` y `/sucursal-disponibilidad/:id`.
void capturasDeSucursales(
  Dispositivo d, {
  bool todosLosEstados = false,
  Set<String> omitidas = const {},
}) {
  final sucursales = [
    Sucursal(id: 1, nombre: 'Central'),
    Sucursal(id: 2, nombre: 'Norte'),
    Sucursal(id: 3, nombre: 'Mercado Campesino'),
  ];

  /// La misma pantalla en `/` ([gestion] = false) y `/sucursales` (true).
  Future<void> montarSucursales(WidgetTester tester,
      {required bool gestion}) async {
    final bloc = SucursalesBloc(
      sucursalesRepository: FakeSucursalesRepository(sucursales: sucursales),
    );
    addTearDown(bloc.close);
    await d.montar(
      tester,
      BlocProvider.value(value: bloc, child: SucursalesScreen(gestion)),
    );
  }

  /// `/sucursal/:id` (0 = alta), como en app_router.
  Future<void> montarSucursal(WidgetTester tester, int id) async {
    final repo = FakeSucursalesRepository(sucursales: sucursales);
    final sucursalesBloc = SucursalesBloc(sucursalesRepository: repo);
    addTearDown(sucursalesBloc.close);
    await d.montar(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: sucursalesBloc),
          BlocProvider(
            create: (_) => SucursalBloc(sucursalesRepository: repo, id: id),
          ),
        ],
        child: SucursalScreen(id: id),
      ),
    );
  }

  testWidgets('inicio (venta de telas)',
      skip: omitidas.contains('sucursales_inicio'), (tester) async {
    await montarSucursales(tester, gestion: false);

    await d.comparar('sucursales_inicio');
  });

  testWidgets('gestión de sucursales',
      skip: omitidas.contains('sucursales_gestion'), (tester) async {
    await montarSucursales(tester, gestion: true);

    await d.comparar('sucursales_gestion');
  });

  testWidgets('formulario de la sucursal (edición)',
      skip: omitidas.contains('sucursal_edicion'), (tester) async {
    await montarSucursal(tester, 3);

    await d.comparar('sucursal_edicion');
  });

  if (todosLosEstados) {
    testWidgets('formulario de la sucursal (alta)',
        skip: omitidas.contains('sucursal_alta'), (tester) async {
      await montarSucursal(tester, 0);

      await d.comparar('sucursal_alta');
    });
  }

  testWidgets('telas que se venden en la sucursal',
      skip: omitidas.contains('sucursal_disponibilidad'), (tester) async {
    final cubit = SucursalDisponibilidadCubit(
      sucursalesRepository: FakeSucursalesRepository(telasSucursal: const [
        TelaSucursal(idtela: 1, nombre: 'Lino', disponible: true),
        TelaSucursal(idtela: 2, nombre: 'Seda', disponible: false),
        TelaSucursal(idtela: 3, nombre: 'Gabardina', disponible: true),
        TelaSucursal(idtela: 4, nombre: 'Popelina', disponible: false),
        TelaSucursal(idtela: 5, nombre: 'Tul', disponible: true),
      ]),
      idsucursal: 1,
    );
    addTearDown(cubit.close);
    await d.montar(
      tester,
      BlocProvider.value(
        value: cubit,
        child: const SucursalDisponibilidadScreen(),
      ),
    );

    await d.comparar('sucursal_disponibilidad');
  });
}
