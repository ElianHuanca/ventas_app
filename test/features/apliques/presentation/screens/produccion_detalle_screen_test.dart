import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';

import '../../../../helpers/fake_repositories.dart';

/// Repo cuyo detalle de producción queda pendiente hasta completar [carga].
class _RepoLento extends FakeApliquesRepository {
  final carga = Completer<List<Produccion>>();

  @override
  Future<List<Produccion>> getDetalleProduccion(int idproduccion) =>
      carga.future;
}

void main() {
  late FakeApliquesRepository repo;
  late DetalleProduccionCubit cubit;

  const lineas = [
    Produccion(
      id: 1,
      fecha: '2024-05-10',
      sucursalNombre: 'Casa Central',
      apliqueNombre: 'Flor',
      colorNombre: 'Rojo',
      hex: '#FF0000',
      cantidad: 3,
    ),
    Produccion(
      id: 2,
      fecha: '2024-05-10',
      sucursalNombre: 'Casa Central',
      apliqueNombre: 'Luna',
      colorNombre: 'Azul',
      hex: '#0000FF',
      cantidad: 1.5,
    ),
  ];

  setUp(() {
    repo = FakeApliquesRepository(detalleProduccion: lineas);
  });

  Future<void> montar(WidgetTester tester, {bool esperar = true}) async {
    cubit = DetalleProduccionCubit(apliquesRepository: repo, idproduccion: 8);
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: const ProduccionDetalleScreen(idproduccion: 8),
      ),
    ));
    if (esperar) await tester.pumpAndSettle();
  }

  testWidgets('muestra cada línea como "Aplique (Color)" con "N uds"',
      (tester) async {
    await montar(tester);

    expect(repo.lastGetDetalleProduccionId, 8);

    expect(find.text('Flor (Rojo)'), findsOneWidget);
    expect(find.text('3.0 uds'), findsOneWidget);
    expect(find.text('Luna (Azul)'), findsOneWidget);
    expect(find.text('1.5 uds'), findsOneWidget);
    // La sucursal va de subtítulo en cada línea
    expect(find.text('Casa Central'), findsNWidgets(2));
  });

  testWidgets('cada línea muestra el color de su hex', (tester) async {
    await montar(tester);

    final avatares = tester
        .widgetList<CircleAvatar>(find.byType(CircleAvatar))
        .map((a) => a.backgroundColor)
        .toList();
    expect(avatares, const [Color(0xFFFF0000), Color(0xFF0000FF)]);
  });

  testWidgets('el título es la fecha de la producción (d-m-aaaa)',
      (tester) async {
    await montar(tester);

    expect(find.text('10-5-2024'), findsOneWidget);
    expect(find.text('Detalle'), findsNothing);
  });

  testWidgets('con una fecha no parseable el título es "Detalle"',
      (tester) async {
    repo = FakeApliquesRepository(detalleProduccion: const [
      Produccion(
        id: 1,
        fecha: 'basura',
        sucursalNombre: 'Casa Central',
        apliqueNombre: 'Flor',
        colorNombre: 'Rojo',
        cantidad: 3,
      ),
    ]);
    await montar(tester);

    expect(find.text('Detalle'), findsOneWidget);
    expect(find.text('Flor (Rojo)'), findsOneWidget);
  });

  testWidgets('sin líneas muestra el estado vacío y el título "Detalle"',
      (tester) async {
    repo = FakeApliquesRepository();
    await montar(tester);

    expect(
        find.text('Todavía no hay producciones registradas'), findsOneWidget);
    expect(find.text('Detalle'), findsOneWidget);
    expect(find.textContaining('uds'), findsNothing);
  });

  testWidgets('mientras carga muestra el loader y después las líneas',
      (tester) async {
    final lento = _RepoLento();
    repo = lento;
    await montar(tester, esperar: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Todavía no hay producciones registradas'), findsNothing);

    lento.carga.complete(lineas);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Flor (Rojo)'), findsOneWidget);
    expect(find.text('10-5-2024'), findsOneWidget);
  });
}
