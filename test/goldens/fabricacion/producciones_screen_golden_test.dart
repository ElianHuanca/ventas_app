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

/// Repo cuyas producciones quedan pendientes hasta completar [carga].
class _RepoLento extends FakeApliquesRepository {
  final carga = Completer<List<ProduccionCabecera>>();

  @override
  Future<List<ProduccionCabecera>> getProducciones(int sucursalId) =>
      carga.future;
}

void main() {
  // Una cabecera por día, la más reciente primero (como la devuelve la base)
  final producciones = [
    ProduccionCabecera(id: 14, fecha: DateTime(2026, 10, 3)),
    ProduccionCabecera(id: 12, fecha: DateTime(2026, 10, 1)),
    ProduccionCabecera(id: 9, fecha: DateTime(2026, 9, 26)),
    ProduccionCabecera(id: 5, fecha: DateTime(2026, 9, 15)),
    ProduccionCabecera(id: 2, fecha: DateTime(2026, 8, 30)),
  ];

  Future<void> montar(
    WidgetTester tester,
    FakeApliquesRepository repo, {
    bool asentar = true,
  }) async {
    final bloc = ProduccionesBloc(apliquesRepository: repo, idsucursal: 1);
    addTearDown(bloc.close);
    await montarParaCaptura(
      tester,
      BlocProvider.value(
        value: bloc,
        child: const ProduccionesScreen(idsucursal: 1),
      ),
      asentar: asentar,
    );
  }

  testWidgets('una tarjeta por día de fabricación', (tester) async {
    await montar(tester, FakeApliquesRepository(producciones: producciones));

    await compararCaptura('producciones_screen_lista');
  });

  testWidgets('sin producciones', (tester) async {
    await montar(tester, FakeApliquesRepository());

    await compararCaptura('producciones_screen_vacia');
  });

  testWidgets('cargando', (tester) async {
    final repo = _RepoLento();
    await montar(tester, repo, asentar: false);
    // En el instante 0 el arco del spinner mide 0: se avanza un tramo fijo
    await tester.pump(const Duration(milliseconds: 400));

    // Se libera la carga aunque la captura falle: si no, el close() del
    // bloc espera ese handler y el test se cuelga hasta el timeout.
    try {
      await compararCaptura('producciones_screen_cargando');
    } finally {
      repo.carga.complete(const []);
    }
    await tester.pumpAndSettle();
  });
}
