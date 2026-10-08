import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';

import '../../../../helpers/fake_repositories.dart';

void main() {
  late FakeApliquesRepository repo;
  late ApliqueColoresCubit cubit;

  // Desordenados a propósito: la pantalla los muestra alfabéticamente
  const colores = [
    ColorItem(id: 1, nombre: 'rojo', hex: 'FF0000', vinculado: true),
    ColorItem(id: 2, nombre: 'Verde', hex: '00FF00', vinculado: false),
    ColorItem(id: 3, nombre: 'Azul', hex: '0000FF', vinculado: true),
  ];

  setUp(() {
    repo = FakeApliquesRepository(
      apliques: [
        Aplique(id: 7, nombre: 'Flor Petalo - Bolsa x100 und', activo: false),
      ],
      colores: colores,
    );
  });

  Future<void> montar(WidgetTester tester, {int idaplique = 7}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    cubit = ApliqueColoresCubit(apliquesRepository: repo, idaplique: idaplique);
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: ApliqueColoresScreen(idaplique: idaplique),
      ),
    ));
    await tester.pumpAndSettle();
  }

  SwitchListTile switchDe(WidgetTester tester, String color) =>
      tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, color));

  List<String> nombresEnPantalla(WidgetTester tester) => tester
      .widgetList<SwitchListTile>(find.byType(SwitchListTile))
      .map((s) => (s.title! as Text).data!)
      .toList();

  testWidgets('el título es el nombre del aplique sin la presentación',
      (tester) async {
    await montar(tester);

    // Aunque el aplique esté inactivo se resuelve su nombre
    expect(repo.lastGetColoresApliqueId, 7);
    expect(find.text('Flor Petalo'), findsOneWidget);
    expect(find.text('Flor Petalo - Bolsa x100 und'), findsNothing);
  });

  testWidgets('sin nombre de aplique usa el título genérico', (tester) async {
    await montar(tester, idaplique: 99);

    expect(find.text('Colores del aplique'), findsOneWidget);
  });

  testWidgets('muestra un switch por color, ordenados sin distinguir mayúsculas',
      (tester) async {
    await montar(tester);

    expect(find.byType(SwitchListTile), findsNWidgets(3));
    expect(nombresEnPantalla(tester), ['Azul', 'rojo', 'Verde']);
    expect(switchDe(tester, 'Azul').value, true);
    expect(switchDe(tester, 'rojo').value, true);
    expect(switchDe(tester, 'Verde').value, false);
  });

  testWidgets('encender un color lo vincula con setColorAplique',
      (tester) async {
    await montar(tester);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Verde'));
    await tester.pumpAndSettle();

    expect(repo.setColorApliqueCalls, [
      [7, 2, true]
    ]);
    expect(switchDe(tester, 'Verde').value, true);
    // Los demás no cambian y el orden se mantiene
    expect(switchDe(tester, 'Azul').value, true);
    expect(switchDe(tester, 'rojo').value, true);
    expect(nombresEnPantalla(tester), ['Azul', 'rojo', 'Verde']);
  });

  testWidgets('apagar un color lo desvincula (baja lógica)', (tester) async {
    await montar(tester);

    await tester.tap(find.widgetWithText(SwitchListTile, 'rojo'));
    await tester.pumpAndSettle();

    expect(repo.setColorApliqueCalls, [
      [7, 1, false]
    ]);
    expect(switchDe(tester, 'rojo').value, false);
  });

  testWidgets('si el repo falla, el switch queda como estaba', (tester) async {
    await montar(tester);
    repo.error = Exception('sin conexión');

    await tester.tap(find.widgetWithText(SwitchListTile, 'Azul'));
    await tester.pumpAndSettle();

    expect(repo.setColorApliqueCalls, isEmpty);
    expect(switchDe(tester, 'Azul').value, true);
  });
}
