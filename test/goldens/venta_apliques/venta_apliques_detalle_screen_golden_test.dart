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
class _RepoLento extends FakeVentasApliquesRepository {
  final carga = Completer<List<DetalleVentaAplique>>();

  @override
  Future<List<DetalleVentaAplique>> getDetalleVentasApliques(int idventa) =>
      carga.future;
}

void main() {
  // Líneas de la venta del día: una por aplique+color+precio
  const lineas = [
    DetalleVentaAplique(
      id: 1,
      nombre: 'Flor bordada 10x10 (Rojo)',
      cantidad: 3,
      precio: 25,
      total: 75,
    ),
    DetalleVentaAplique(
      id: 2,
      nombre: 'Flor bordada 10x10 (Azul marino)',
      cantidad: 2,
      precio: 25,
      total: 50,
    ),
    DetalleVentaAplique(
      id: 3,
      nombre: 'Corazón 5x5 (Rojo)',
      cantidad: 6,
      precio: 8,
      total: 48,
    ),
    DetalleVentaAplique(
      id: 4,
      nombre: 'Mariposa 8x6 (Dorado)',
      cantidad: 1,
      precio: 18.5,
      total: 18.5,
    ),
  ];
  final fecha = DateTime(2026, 10, 10);

  Future<void> montar(
    WidgetTester tester,
    FakeVentasApliquesRepository repo, {
    bool asentar = true,
  }) async {
    final cubit =
        DetalleVentaApliquesCubit(ventasApliquesRepository: repo, idventa: 48);
    addTearDown(cubit.close);
    await montarParaCaptura(
      tester,
      BlocProvider.value(
        value: cubit,
        child: VentaApliquesDetalleScreen(idventa: 48, fecha: fecha),
      ),
      asentar: asentar,
    );
  }

  testWidgets('líneas de la venta con su total', (tester) async {
    await montar(tester, FakeVentasApliquesRepository(detalle: lineas));

    await compararCaptura('venta_apliques_detalle_lineas');
  });

  testWidgets('venta sin líneas', (tester) async {
    await montar(tester, FakeVentasApliquesRepository());

    await compararCaptura('venta_apliques_detalle_vacia');
  });

  testWidgets('cargando', (tester) async {
    final lento = _RepoLento();
    await montar(tester, lento, asentar: false);
    // Avanza el reloj de prueba para que el arco del loader se vea (en t=0
    // es un punto); el tiempo es falso, así que la captura es fija.
    await tester.pump(const Duration(milliseconds: 400));

    await compararCaptura('venta_apliques_detalle_cargando');

    lento.carga.complete(lineas);
    await tester.pumpAndSettle();
  });
}
