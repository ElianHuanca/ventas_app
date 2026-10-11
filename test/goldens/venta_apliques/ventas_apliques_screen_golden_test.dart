@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

/// Repo cuyo historial queda pendiente hasta completar [carga].
class _RepoLento extends FakeVentasApliquesRepository {
  final carga = Completer<List<VentaAplique>>();

  @override
  Future<List<VentaAplique>> getVentasApliques(int idsucursal) => carga.future;
}

void main() {
  // Una venta por día (la más reciente primero, como la devuelve la RPC)
  final ventas = [
    VentaAplique(id: 48, fecha: DateTime(2026, 10, 10)),
    VentaAplique(id: 47, fecha: DateTime(2026, 10, 9)),
    VentaAplique(id: 45, fecha: DateTime(2026, 10, 7)),
    VentaAplique(id: 44, fecha: DateTime(2026, 10, 6)),
    VentaAplique(id: 41, fecha: DateTime(2026, 10, 3)),
  ];

  Future<void> montar(
    WidgetTester tester,
    FakeVentasApliquesRepository repo, {
    bool asentar = true,
  }) async {
    final bloc =
        VentasApliquesBloc(ventasApliquesRepository: repo, idsucursal: 1);
    addTearDown(bloc.close);
    await montarParaCaptura(
      tester,
      BlocProvider.value(
        value: bloc,
        child: const VentasApliquesScreen(idsucursal: 1),
      ),
      asentar: asentar,
    );
  }

  testWidgets('una tarjeta por día con ventas', (tester) async {
    await montar(tester, FakeVentasApliquesRepository(ventas: ventas));

    await compararCaptura('ventas_apliques_lista');
  });

  testWidgets('sucursal sin ventas', (tester) async {
    await montar(tester, FakeVentasApliquesRepository());

    await compararCaptura('ventas_apliques_vacia');
  });

  testWidgets('cargando', (tester) async {
    final lento = _RepoLento();
    await montar(tester, lento, asentar: false);
    // Avanza el reloj de prueba para que el arco del loader se vea (en t=0
    // es un punto); el tiempo es falso, así que la captura es fija.
    await tester.pump(const Duration(milliseconds: 400));

    await compararCaptura('ventas_apliques_cargando');

    lento.carga.complete(ventas);
    await tester.pumpAndSettle();
  });
}
