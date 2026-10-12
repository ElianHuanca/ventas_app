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

/// Repo cuyos colores quedan pendientes hasta completar [carga].
class _RepoLento extends FakeApliquesRepository {
  final carga = Completer<List<ColorItem>>();

  @override
  Future<List<ColorItem>> getColoresAplique(int idaplique) => carga.future;
}

void main() {
  final apliques = [
    Aplique(
      id: 7,
      nombre: 'Flor bordada 10x10 - Bolsa x100 und',
      costoFabricacion: 12.5,
      anchoCm: 10,
      altoCm: 10,
    ),
  ];

  // Desordenados a propósito: el cubit los ordena alfabéticamente
  const colores = [
    ColorItem(id: 1, nombre: 'Rojo', hex: '#C62828', vinculado: true),
    ColorItem(id: 2, nombre: 'Azul marino', hex: '#1A237E', vinculado: true),
    ColorItem(id: 3, nombre: 'Blanco', hex: '#FFFFFF', vinculado: false),
    ColorItem(id: 4, nombre: 'Dorado', hex: '#D4AF37', vinculado: true),
    ColorItem(
        id: 5, nombre: 'Verde esmeralda', hex: '#2E7D32', vinculado: false),
    ColorItem(id: 6, nombre: 'Negro', hex: '#000000', vinculado: false),
  ];

  Future<void> montar(
    WidgetTester tester,
    FakeApliquesRepository repo, {
    bool asentar = true,
  }) async {
    final cubit = ApliqueColoresCubit(apliquesRepository: repo, idaplique: 7);
    addTearDown(cubit.close);
    await montarParaCaptura(
      tester,
      BlocProvider.value(
        value: cubit,
        child: const ApliqueColoresScreen(idaplique: 7),
      ),
      asentar: asentar,
    );
  }

  testWidgets('colores vinculados y no vinculados', (tester) async {
    await montar(
      tester,
      FakeApliquesRepository(apliques: apliques, colores: colores),
    );

    await compararCaptura('aplique_colores_screen_vinculados');
  });

  testWidgets('cargando', (tester) async {
    final repo = _RepoLento();
    await montar(tester, repo, asentar: false);
    // En el instante 0 el arco del spinner mide 0: se avanza un tramo fijo
    await tester.pump(const Duration(milliseconds: 400));

    // Se libera la carga aunque la captura falle (con un Bloc, su close()
    // esperaría el handler pendiente y el test se colgaría).
    try {
      await compararCaptura('aplique_colores_screen_cargando');
    } finally {
      repo.carga.complete(const []);
    }
    await tester.pumpAndSettle();
  });
}
