@Tags(['golden'])
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/sucursales/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import 'chica_helpers.dart';

// `/`, `/sucursales`, `/sucursal/:id` y `/sucursal-disponibilidad/:id`.
void main() {
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
    await montarChica(
      tester,
      BlocProvider.value(value: bloc, child: SucursalesScreen(gestion)),
    );
  }

  testWidgets('inicio (venta de telas)', (tester) async {
    await montarSucursales(tester, gestion: false);

    await compararChica('sucursales_inicio');
  });

  testWidgets('gestión de sucursales', (tester) async {
    await montarSucursales(tester, gestion: true);

    await compararChica('sucursales_gestion');
  });

  testWidgets('formulario de la sucursal (edición)', (tester) async {
    final repo = FakeSucursalesRepository(sucursales: sucursales);
    final sucursalesBloc = SucursalesBloc(sucursalesRepository: repo);
    addTearDown(sucursalesBloc.close);
    await montarChica(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: sucursalesBloc),
          BlocProvider(
            create: (_) => SucursalBloc(sucursalesRepository: repo, id: 3),
          ),
        ],
        child: const SucursalScreen(id: 3),
      ),
    );

    await compararChica('sucursal_edicion');
  });

  testWidgets('telas que se venden en la sucursal', (tester) async {
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
    await montarChica(
      tester,
      BlocProvider.value(
        value: cubit,
        child: const SucursalDisponibilidadScreen(),
      ),
    );

    await compararChica('sucursal_disponibilidad');
  });
}
