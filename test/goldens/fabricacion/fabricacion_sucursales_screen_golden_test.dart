@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

/// Repo cuya carga de sucursales queda pendiente hasta completar [carga].
class _RepoLento extends FakeSucursalesRepository {
  final carga = Completer<List<Sucursal>>();

  @override
  Future<List<Sucursal>> getSucursales() => carga.future;
}

void main() {
  final sucursales = [
    Sucursal(id: 1, nombre: 'Central'),
    Sucursal(id: 2, nombre: 'Norte'),
    Sucursal(id: 3, nombre: 'Mercado Campesino'),
  ];

  /// El SucursalesBloc es global en la app (main.dart): acá se inyecta.
  Future<void> montar(
    WidgetTester tester,
    FakeSucursalesRepository repo, {
    bool asentar = true,
  }) async {
    final bloc = SucursalesBloc(sucursalesRepository: repo);
    addTearDown(bloc.close);
    await montarParaCaptura(
      tester,
      BlocProvider.value(
        value: bloc,
        child: const FabricacionSucursalesScreen(),
      ),
      asentar: asentar,
    );
  }

  testWidgets('una tarjeta por sucursal', (tester) async {
    await montar(tester, FakeSucursalesRepository(sucursales: sucursales));

    await compararCaptura('fabricacion_sucursales_screen_lista');
  });

  testWidgets('sin sucursales', (tester) async {
    await montar(tester, FakeSucursalesRepository());

    await compararCaptura('fabricacion_sucursales_screen_vacia');
  });

  testWidgets('cargando', (tester) async {
    final repo = _RepoLento();
    await montar(tester, repo, asentar: false);
    // En el instante 0 el arco del spinner mide 0: se avanza un tramo fijo
    await tester.pump(const Duration(milliseconds: 400));

    // Se libera la carga aunque la captura falle: si no, el close() del
    // bloc espera ese handler y el test se cuelga hasta el timeout.
    try {
      await compararCaptura('fabricacion_sucursales_screen_cargando');
    } finally {
      repo.carga.complete(const []);
    }
    await tester.pumpAndSettle();
  });
}
