import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/colores/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/colores/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

/// `/colores` y `/color/:id`.
void capturasDeColores(
  Dispositivo d, {
  bool todosLosEstados = false,
  Set<String> omitidas = const {},
}) {
  const colores = [
    ColorItem(id: 1, nombre: 'Rojo carmesí', hex: 'C0392B'),
    ColorItem(id: 2, nombre: 'Azul marino', hex: '000080'),
    ColorItem(id: 3, nombre: 'Dorado', hex: 'D4AF37'),
    ColorItem(id: 4, nombre: 'Verde esmeralda', hex: '50C878'),
    ColorItem(id: 5, nombre: 'Coral', hex: 'FF7F50'),
    ColorItem(id: 6, nombre: 'Negro', hex: '000000'),
    ColorItem(id: 7, nombre: 'Blanco', hex: 'FFFFFF'),
  ];

  /// `/color/:id` (0 = alta) con el ColoresBloc de la ruta.
  Future<void> montarColor(WidgetTester tester, int id) async {
    final bloc = ColoresBloc(
      coloresRepository: FakeColoresRepository(colores: colores),
    );
    addTearDown(bloc.close);
    await d.montar(
      tester,
      BlocProvider.value(value: bloc, child: ColorScreen(id: id)),
    );
  }

  testWidgets('listado de colores', skip: omitidas.contains('colores'),
      (tester) async {
    final bloc = ColoresBloc(
      coloresRepository: FakeColoresRepository(colores: colores),
    );
    addTearDown(bloc.close);
    await d.montar(
      tester,
      BlocProvider.value(value: bloc, child: const ColoresScreen()),
    );

    await d.comparar('colores');
  });

  testWidgets('formulario del color (edición)',
      skip: omitidas.contains('color_edicion'), (tester) async {
    await montarColor(tester, 4);

    await d.comparar('color_edicion');
  });

  if (todosLosEstados) {
    testWidgets('formulario del color (alta)',
        skip: omitidas.contains('color_alta'), (tester) async {
      await montarColor(tester, 0);

      await d.comparar('color_alta');
    });
  }
}
