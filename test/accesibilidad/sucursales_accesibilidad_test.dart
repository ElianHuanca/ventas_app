import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/sucursales/presentation/screens/screens.dart';

import '../helpers/fake_repositories.dart';
import 'accesibilidad_helpers.dart';

void main() {
  FakeSucursalesRepository repoConDatos() => FakeSucursalesRepository(
        sucursales: [
          Sucursal(id: 1, nombre: 'Central'),
          Sucursal(id: 2, nombre: 'Norte'),
          Sucursal(id: 3, nombre: 'Sur'),
        ],
        telasSucursal: const [
          TelaSucursal(idtela: 1, nombre: 'Lino', disponible: true),
          TelaSucursal(idtela: 2, nombre: 'Seda', disponible: false),
          TelaSucursal(idtela: 3, nombre: 'Gabardina', disponible: true),
        ],
      );

  /// La misma pantalla está en `/` (venta de telas) y en `/sucursales`
  /// (gestión). El SucursalesBloc es global en la app (main.dart).
  Future<void> montarListado(WidgetTester tester, {required bool gestion}) {
    final bloc = SucursalesBloc(sucursalesRepository: repoConDatos());
    addTearDown(bloc.close);
    return montarPantalla(
      tester,
      BlocProvider.value(value: bloc, child: SucursalesScreen(gestion)),
    );
  }

  /// `/sucursal/:id` como en app_router: SucursalesBloc global +
  /// SucursalBloc de la ruta.
  Future<void> montarFormulario(WidgetTester tester, {required int id}) {
    final repo = repoConDatos();
    final sucursalesBloc = SucursalesBloc(sucursalesRepository: repo);
    addTearDown(sucursalesBloc.close);
    return montarPantalla(
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

  group('/ (SucursalesScreen, venta de telas)', () {
    verificarGuias(
        'una tarjeta por sucursal', (t) => montarListado(t, gestion: false));
  });

  group('/sucursales (SucursalesScreen, gestión)', () {
    verificarGuias('las sucursales y la tarjeta para agregar',
        (t) => montarListado(t, gestion: true));
  });

  group('/sucursal/:idsucursal (SucursalScreen)', () {
    verificarGuias('alta', (t) => montarFormulario(t, id: 0));
    verificarGuias('edición', (t) => montarFormulario(t, id: 2));
  });

  group(
      '/sucursal-disponibilidad/:idsucursal '
      '(SucursalDisponibilidadScreen)', () {
    verificarGuias('telas vinculadas y no vinculadas', (tester) {
      final cubit = SucursalDisponibilidadCubit(
        sucursalesRepository: repoConDatos(),
        idsucursal: 1,
      );
      addTearDown(cubit.close);
      return montarPantalla(
        tester,
        BlocProvider.value(
          value: cubit,
          child: const SucursalDisponibilidadScreen(),
        ),
      );
    });
  });
}
