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
    Sucursal(id: 1, nombre: 'Casa Central'),
    Sucursal(id: 2, nombre: 'Mercado Campesino'),
    Sucursal(id: 3, nombre: 'La Ramada'),
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
        child: const VentaApliquesSucursalesScreen(),
      ),
      asentar: asentar,
    );
  }

  testWidgets('una tarjeta por sucursal', (tester) async {
    await montar(tester, FakeSucursalesRepository(sucursales: sucursales));

    await compararCaptura('venta_apliques_sucursales_lista');
  });

  testWidgets('sin sucursales', (tester) async {
    await montar(tester, FakeSucursalesRepository());

    await compararCaptura('venta_apliques_sucursales_vacia');
  });

  testWidgets('cargando', (tester) async {
    final lento = _RepoLento();
    await montar(tester, lento, asentar: false);
    // Avanza el reloj de prueba para que el arco del loader se vea (en t=0
    // es un punto); el tiempo es falso, así que la captura es fija.
    await tester.pump(const Duration(milliseconds: 400));

    await compararCaptura('venta_apliques_sucursales_cargando');

    lento.carga.complete(sucursales);
    await tester.pumpAndSettle();
  });
}
