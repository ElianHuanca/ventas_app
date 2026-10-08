import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';

import '../../../../helpers/fake_repositories.dart';

/// Repo cuyo detalle queda pendiente hasta completar [carga].
class _RepoLento extends FakeVentasApliquesRepository {
  final carga = Completer<List<DetalleVentaAplique>>();

  @override
  Future<List<DetalleVentaAplique>> getDetalleVentasApliques(int idventa) =>
      carga.future;
}

void main() {
  late FakeVentasApliquesRepository repo;
  late DetalleVentaApliquesCubit cubit;

  const lineas = [
    DetalleVentaAplique(
        id: 1, nombre: 'Flor (Rojo)', cantidad: 2, precio: 25, total: 50),
    DetalleVentaAplique(
        id: 2, nombre: 'Luna (Azul)', cantidad: 1.5, precio: 10, total: 15),
  ];

  setUp(() {
    repo = FakeVentasApliquesRepository(detalle: lineas);
  });

  Future<void> montar(
    WidgetTester tester, {
    DateTime? fecha,
    bool esperar = true,
  }) async {
    cubit =
        DetalleVentaApliquesCubit(ventasApliquesRepository: repo, idventa: 21);
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: VentaApliquesDetalleScreen(idventa: 21, fecha: fecha),
      ),
    ));
    if (esperar) await tester.pumpAndSettle();
  }

  testWidgets('muestra cada línea con "X uds x Y Bs" y su total',
      (tester) async {
    await montar(tester, fecha: DateTime(2024, 5, 10));

    expect(repo.lastGetDetalleIdventa, 21);

    expect(find.text('Flor (Rojo)'), findsOneWidget);
    expect(find.text('2.0 uds x 25.0 Bs'), findsOneWidget);
    expect(find.text('50.0 Bs'), findsOneWidget);

    expect(find.text('Luna (Azul)'), findsOneWidget);
    expect(find.text('1.5 uds x 10.0 Bs'), findsOneWidget);
    expect(find.text('15.0 Bs'), findsOneWidget);
  });

  testWidgets('muestra el total de la venta sumando las líneas',
      (tester) async {
    await montar(tester, fecha: DateTime(2024, 5, 10));

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('65.0 Bs'), findsOneWidget);
  });

  testWidgets('el título es la fecha de la venta (d-m-aaaa)', (tester) async {
    await montar(tester, fecha: DateTime(2024, 5, 10, 15, 30));

    expect(find.text('10-5-2024'), findsOneWidget);
    expect(find.text('Detalle'), findsNothing);
  });

  testWidgets('sin fecha el título es "Detalle"', (tester) async {
    await montar(tester);

    expect(find.text('Detalle'), findsOneWidget);
  });

  testWidgets('venta sin líneas muestra el estado vacío y ningún total',
      (tester) async {
    repo = FakeVentasApliquesRepository();
    await montar(tester, fecha: DateTime(2024, 5, 10));

    expect(find.text('Venta sin líneas'), findsOneWidget);
    expect(find.text('Total'), findsNothing);
    expect(find.textContaining('Bs'), findsNothing);
  });

  testWidgets('mientras carga muestra el loader y después las líneas',
      (tester) async {
    final lento = _RepoLento();
    repo = lento;
    await montar(tester, esperar: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Venta sin líneas'), findsNothing);

    lento.carga.complete(lineas);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Flor (Rojo)'), findsOneWidget);
  });
}
