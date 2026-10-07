import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';
import 'package:textiles_app/features/colores/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/colores/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';

// Regresión: el formulario de edición se armaba con el estado inicial (lista
// vacía → id 0) y, si la carga llegaba antes del siguiente frame, el cubit
// quedaba con id 0: título "Editar", botón "Guardar" y al guardar creaba un
// duplicado. Los fakes responden al instante, que es justo ese caso.
void main() {
  testWidgets('editar un color arma el formulario con ese color',
      (tester) async {
    final repo = FakeColoresRepository(colores: const [
      ColorItem(id: 5, nombre: 'Coral', hex: 'FF7F50'),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider(
        create: (_) => ColoresBloc(coloresRepository: repo),
        child: const ColorScreen(id: 5),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Editar Color'), findsOneWidget);
    expect(find.text('Modificar'), findsOneWidget);
    expect(find.text('Guardar'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Coral'), findsOneWidget);

    await tester.tap(find.text('Modificar'));
    await tester.pump();
    expect(repo.actualizado, isNotNull);
    expect(repo.creado, isNull);
  });

  testWidgets('editar un aplique arma el formulario con ese aplique',
      (tester) async {
    final repo = FakeApliquesRepository(apliques: [
      Aplique(id: 7, nombre: 'Estrella'),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider(
        create: (_) => ApliquesBloc(apliquesRepository: repo),
        child: const ApliqueScreen(id: 7),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Editar Aplique'), findsOneWidget);
    expect(find.text('Modificar'), findsOneWidget);
    expect(find.text('Guardar'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Estrella'), findsOneWidget);
  });
}
