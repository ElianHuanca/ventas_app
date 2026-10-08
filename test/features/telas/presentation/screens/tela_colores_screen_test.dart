import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/telas/presentation/screens/screens.dart';

import '../../../../helpers/fake_repositories.dart';

void main() {
  late FakeTelasRepository repo;
  late TelaColoresCubit cubit;

  const colores = [
    ColorItem(id: 1, nombre: 'Rojo', hex: 'FF0000', vinculado: true),
    ColorItem(id: 2, nombre: 'Verde', hex: '00FF00', vinculado: false),
    ColorItem(id: 3, nombre: 'Azul', hex: '0000FF', vinculado: true),
  ];

  setUp(() {
    repo = FakeTelasRepository(
      telas: [Tela(id: 7, nombre: 'Lino')],
      colores: colores,
    );
  });

  Future<void> montar(WidgetTester tester, {int idtela = 7}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    cubit = TelaColoresCubit(telasRepository: repo, idtela: idtela);
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: TelaColoresScreen(idtela: idtela),
      ),
    ));
    await tester.pumpAndSettle();
  }

  SwitchListTile switchDe(WidgetTester tester, String color) =>
      tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, color));

  testWidgets('el título es el nombre de la tela y hay un switch por color',
      (tester) async {
    await montar(tester);

    expect(find.text('Lino'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(3));
    expect(switchDe(tester, 'Rojo').value, true);
    expect(switchDe(tester, 'Verde').value, false);
    expect(switchDe(tester, 'Azul').value, true);
  });

  testWidgets('cada color muestra su muestra con el hex', (tester) async {
    await montar(tester);

    final muestra = tester.widget<CircleAvatar>(find.descendant(
      of: find.widgetWithText(SwitchListTile, 'Verde'),
      matching: find.byType(CircleAvatar),
    ));
    expect(muestra.backgroundColor, const Color(0xFF00FF00));
  });

  testWidgets('sin nombre de tela usa el título genérico', (tester) async {
    await montar(tester, idtela: 99);

    expect(find.text('Colores de la tela'), findsOneWidget);
  });

  testWidgets('encender un color lo vincula con setColorTela',
      (tester) async {
    await montar(tester);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Verde'));
    await tester.pumpAndSettle();

    expect(repo.setColorTelaCalls, [
      [7, 2, true]
    ]);
    expect(switchDe(tester, 'Verde').value, true);
    // Los demás no cambian
    expect(switchDe(tester, 'Rojo').value, true);
    expect(switchDe(tester, 'Azul').value, true);
  });

  testWidgets('apagar un color lo desvincula (baja lógica)', (tester) async {
    await montar(tester);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Azul'));
    await tester.pumpAndSettle();

    expect(repo.setColorTelaCalls, [
      [7, 3, false]
    ]);
    expect(switchDe(tester, 'Azul').value, false);
  });

  testWidgets('si el repo falla, el switch queda como estaba', (tester) async {
    await montar(tester);
    repo.error = Exception('sin conexión');

    await tester.tap(find.widgetWithText(SwitchListTile, 'Rojo'));
    await tester.pumpAndSettle();

    expect(repo.setColorTelaCalls, isEmpty);
    expect(switchDe(tester, 'Rojo').value, true);
  });
}
