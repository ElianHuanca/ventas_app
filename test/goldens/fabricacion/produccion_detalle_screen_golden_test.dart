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

/// Repo cuyo detalle queda pendiente hasta completar [carga].
class _RepoLento extends FakeApliquesRepository {
  final carga = Completer<List<Produccion>>();

  @override
  Future<List<Produccion>> getDetalleProduccion(int idproduccion) =>
      carga.future;
}

void main() {
  const lineas = [
    Produccion(
      id: 31,
      fecha: '2026-10-03',
      sucursalNombre: 'Central',
      apliqueNombre: 'Flor bordada 10x10',
      colorNombre: 'Rojo',
      hex: '#C62828',
      cantidad: 24,
    ),
    Produccion(
      id: 32,
      fecha: '2026-10-03',
      sucursalNombre: 'Central',
      apliqueNombre: 'Flor bordada 10x10',
      colorNombre: 'Azul marino',
      hex: '#1A237E',
      cantidad: 12,
    ),
    Produccion(
      id: 33,
      fecha: '2026-10-03',
      sucursalNombre: 'Central',
      apliqueNombre: 'Corazón 5x5',
      colorNombre: 'Dorado',
      hex: '#D4AF37',
      cantidad: 50,
    ),
  ];

  Future<void> montar(
    WidgetTester tester,
    FakeApliquesRepository repo, {
    bool asentar = true,
  }) async {
    final cubit =
        DetalleProduccionCubit(apliquesRepository: repo, idproduccion: 14);
    addTearDown(cubit.close);
    await montarParaCaptura(
      tester,
      BlocProvider.value(
        value: cubit,
        child: const ProduccionDetalleScreen(idproduccion: 14),
      ),
      asentar: asentar,
    );
  }

  testWidgets('líneas de la producción del día', (tester) async {
    await montar(tester, FakeApliquesRepository(detalleProduccion: lineas));

    await compararCaptura('produccion_detalle_screen_lineas');
  });

  testWidgets('sin líneas', (tester) async {
    await montar(tester, FakeApliquesRepository());

    await compararCaptura('produccion_detalle_screen_vacia');
  });

  testWidgets('cargando', (tester) async {
    final repo = _RepoLento();
    await montar(tester, repo, asentar: false);
    // En el instante 0 el arco del spinner mide 0: se avanza un tramo fijo
    await tester.pump(const Duration(milliseconds: 400));

    await compararCaptura('produccion_detalle_screen_cargando');

    repo.carga.complete(const []);
    await tester.pumpAndSettle();
  });
}
