import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/sucursales/presentation/screens/screens.dart';

import '../../../../helpers/fake_repositories.dart';

/// Repo cuya carga de telas no termina hasta completar [carga].
class _RepoLento extends FakeSucursalesRepository {
  final carga = Completer<List<TelaSucursal>>();

  @override
  Future<List<TelaSucursal>> getTelasSucursal(int idsucursal) => carga.future;
}

void main() {
  late FakeSucursalesRepository repo;
  late SucursalDisponibilidadCubit cubit;

  const telas = [
    TelaSucursal(idtela: 1, nombre: 'Lino', disponible: true),
    TelaSucursal(idtela: 2, nombre: 'Seda', disponible: false),
  ];

  setUp(() {
    repo = FakeSucursalesRepository(telasSucursal: telas);
  });

  Future<void> montar(WidgetTester tester) async {
    cubit = SucursalDisponibilidadCubit(
        sucursalesRepository: repo, idsucursal: 7);
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: const SucursalDisponibilidadScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Valor actual del switch de la tela [nombre].
  bool valorDe(WidgetTester tester, String nombre) => tester
      .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, nombre))
      .value;

  testWidgets('muestra el título, la ayuda y un switch por tela',
      (tester) async {
    await montar(tester);

    expect(find.text('Disponibilidad de telas'), findsOneWidget);
    expect(
        find.textContaining('la venta muestra todo el catálogo'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(2));
    expect(find.text('Lino'), findsOneWidget);
    expect(find.text('Seda'), findsOneWidget);
  });

  testWidgets('cada switch refleja la disponibilidad de la tela',
      (tester) async {
    await montar(tester);

    expect(valorDe(tester, 'Lino'), true);
    expect(valorDe(tester, 'Seda'), false);
  });

  testWidgets('activar una tela la vincula a la sucursal', (tester) async {
    await montar(tester);

    await tester.tap(find.text('Seda'));
    await tester.pumpAndSettle();

    expect(repo.setTelaSucursalCalls, [
      [2, 7, true],
    ]);
    expect(valorDe(tester, 'Seda'), true);
    expect(valorDe(tester, 'Lino'), true);
  });

  testWidgets('desactivar una tela la desvincula de la sucursal',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(repo.setTelaSucursalCalls, [
      [1, 7, false],
    ]);
    expect(valorDe(tester, 'Lino'), false);
  });

  testWidgets('si el repositorio falla el switch queda como estaba',
      (tester) async {
    await montar(tester);
    repo.error = Exception('sin conexión');

    await tester.tap(find.text('Seda'));
    await tester.pumpAndSettle();

    expect(repo.setTelaSucursalCalls, isEmpty);
    expect(valorDe(tester, 'Seda'), false);
  });

  testWidgets('sin telas solo muestra la ayuda', (tester) async {
    repo = FakeSucursalesRepository();
    await montar(tester);

    expect(find.byType(SwitchListTile), findsNothing);
    expect(
        find.textContaining('la venta muestra todo el catálogo'), findsOneWidget);
  });

  testWidgets('mientras carga muestra el loader', (tester) async {
    final lento = _RepoLento();
    repo = lento;
    cubit = SucursalDisponibilidadCubit(
        sucursalesRepository: repo, idsucursal: 7);
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: const SucursalDisponibilidadScreen(),
      ),
    ));

    expect(find.byType(FullScreenLoader), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);

    lento.carga.complete(telas);
    await tester.pumpAndSettle();

    expect(find.byType(FullScreenLoader), findsNothing);
    expect(find.byType(SwitchListTile), findsNWidgets(2));
  });
}
