import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

/// `/apliques`, `/aplique/:id` y `/aplique-colores/:id`.
void capturasDeApliques(
  Dispositivo d, {
  bool todosLosEstados = false,
  Set<String> omitidas = const {},
}) {
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

  /// `/aplique/:id` (0 = alta).
  Future<void> montarAplique(WidgetTester tester, int id) async {
    final bloc = ApliquesBloc(
      apliquesRepository: FakeApliquesRepository(apliques: apliques),
    );
    addTearDown(bloc.close);
    await d.montar(
      tester,
      BlocProvider.value(value: bloc, child: ApliqueScreen(id: id)),
    );
  }

  testWidgets('listado de apliques', skip: omitidas.contains('apliques'),
      (tester) async {
    final bloc = ApliquesBloc(
      apliquesRepository: FakeApliquesRepository(apliques: apliques),
    );
    addTearDown(bloc.close);
    await d.montar(
      tester,
      BlocProvider.value(value: bloc, child: const ApliquesScreen()),
    );

    await d.comparar('apliques');
  });

  testWidgets('formulario del aplique (edición)',
      skip: omitidas.contains('aplique_edicion'), (tester) async {
    await montarAplique(tester, 1);

    await d.comparar('aplique_edicion');
  });

  if (todosLosEstados) {
    testWidgets('formulario del aplique (alta)',
        skip: omitidas.contains('aplique_alta'), (tester) async {
      await montarAplique(tester, 0);

      await d.comparar('aplique_alta');
    });
  }

  testWidgets('colores del aplique', skip: omitidas.contains('aplique_colores'),
      (tester) async {
    final cubit = ApliqueColoresCubit(
      apliquesRepository: FakeApliquesRepository(
        apliques: apliques,
        colores: const [
          ColorItem(id: 1, nombre: 'Rojo', hex: '#C62828', vinculado: true),
          ColorItem(
              id: 2, nombre: 'Azul marino', hex: '#1A237E', vinculado: true),
          ColorItem(id: 3, nombre: 'Blanco', hex: '#FFFFFF', vinculado: false),
          ColorItem(id: 4, nombre: 'Dorado', hex: '#D4AF37', vinculado: true),
          ColorItem(
              id: 5,
              nombre: 'Verde esmeralda',
              hex: '#2E7D32',
              vinculado: false),
          ColorItem(id: 6, nombre: 'Negro', hex: '#000000', vinculado: false),
        ],
      ),
      idaplique: 1,
    );
    addTearDown(cubit.close);
    await d.montar(
      tester,
      BlocProvider.value(
        value: cubit,
        child: const ApliqueColoresScreen(idaplique: 1),
      ),
    );

    await d.comparar('aplique_colores');
  });
}
