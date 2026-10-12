@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

/// Repo cuyo listado queda pendiente hasta completar [carga].
class _RepoLento extends FakeApliquesRepository {
  final carga = Completer<List<Aplique>>();

  @override
  Future<List<Aplique>> getApliques({bool soloActivos = true}) => carga.future;
}

void main() {
  final apliques = [
    Aplique(
      id: 1,
      nombre: 'Flor bordada 10x10 - Bolsa x100 und',
      costoFabricacion: 12.5,
      anchoCm: 10,
      altoCm: 10,
    ),
    Aplique(
      id: 2,
      nombre: 'Corazón 5x5',
      costoFabricacion: 4,
      anchoCm: 5,
      altoCm: 5,
    ),
    Aplique(
      id: 3,
      nombre: 'Mariposa lentejuela 8x6',
      costoFabricacion: 9.5,
      anchoCm: 8,
      altoCm: 6,
      activo: false,
    ),
    Aplique(id: 4, nombre: 'Estrella dorada', costoFabricacion: 6),
  ];

  Future<ApliquesBloc> montar(
    WidgetTester tester,
    FakeApliquesRepository repo, {
    bool asentar = true,
  }) async {
    final bloc = ApliquesBloc(apliquesRepository: repo);
    addTearDown(bloc.close);
    await montarParaCaptura(
      tester,
      BlocProvider.value(value: bloc, child: const ApliquesScreen()),
      asentar: asentar,
    );
    return bloc;
  }

  testWidgets('lista con activos, inactivos, medidas y costo', (tester) async {
    await montar(tester, FakeApliquesRepository(apliques: apliques));

    await compararCaptura('apliques_screen_lista');
  });

  testWidgets('búsqueda sin resultados', (tester) async {
    await montar(tester, FakeApliquesRepository(apliques: apliques));
    await tester.enterText(find.byType(TextField), 'pez');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await compararCaptura('apliques_screen_sin_resultados');
  });

  testWidgets('sin apliques registrados', (tester) async {
    await montar(tester, FakeApliquesRepository());

    await compararCaptura('apliques_screen_vacia');
  });

  testWidgets('cargando', (tester) async {
    final repo = _RepoLento();
    await montar(tester, repo, asentar: false);
    // En el instante 0 el arco del spinner mide 0: se avanza un tramo fijo
    await tester.pump(const Duration(milliseconds: 400));

    // Se libera la carga aunque la captura falle: si no, el close() del
    // bloc espera ese handler y el test se cuelga hasta el timeout.
    try {
      await compararCaptura('apliques_screen_cargando');
    } finally {
      repo.carga.complete(const []);
    }
    await tester.pumpAndSettle();
  });
}
