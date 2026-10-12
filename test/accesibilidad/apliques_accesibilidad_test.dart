import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';

import '../helpers/fake_repositories.dart';
import 'accesibilidad_helpers.dart';

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
  ];
  const colores = [
    ColorItem(id: 1, nombre: 'Rojo', hex: '#C62828', vinculado: true),
    ColorItem(id: 2, nombre: 'Azul marino', hex: '#1A237E', vinculado: true),
    ColorItem(id: 3, nombre: 'Blanco', hex: '#FFFFFF', vinculado: false),
    ColorItem(id: 4, nombre: 'Dorado', hex: '#D4AF37', vinculado: false),
  ];

  FakeApliquesRepository repoConDatos() =>
      FakeApliquesRepository(apliques: apliques, colores: colores);

  /// `/apliques` y `/aplique/:id` usan el ApliquesBloc de la ruta.
  Future<void> montarConBloc(WidgetTester tester, Widget pantalla) {
    final bloc = ApliquesBloc(apliquesRepository: repoConDatos());
    addTearDown(bloc.close);
    return montarPantalla(
      tester,
      BlocProvider.value(value: bloc, child: pantalla),
    );
  }

  group('/apliques (ApliquesScreen)', () {
    verificarGuias('lista con activos, inactivos, medidas y costo',
        (t) => montarConBloc(t, const ApliquesScreen()));
  });

  group('/aplique/:idaplique (ApliqueScreen)', () {
    verificarGuias('alta', (t) => montarConBloc(t, const ApliqueScreen(id: 0)));
    verificarGuias(
        'edición', (t) => montarConBloc(t, const ApliqueScreen(id: 1)));
  });

  group('/aplique-colores/:idaplique (ApliqueColoresScreen)', () {
    verificarGuias('colores vinculados y no vinculados', (tester) {
      final cubit =
          ApliqueColoresCubit(apliquesRepository: repoConDatos(), idaplique: 1);
      addTearDown(cubit.close);
      return montarPantalla(
        tester,
        BlocProvider.value(
          value: cubit,
          child: const ApliqueColoresScreen(idaplique: 1),
        ),
      );
    });
  });
}
