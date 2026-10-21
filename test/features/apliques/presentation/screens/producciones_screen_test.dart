import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';

import '../../../../helpers/fake_repositories.dart';

void main() {
  late FakeApliquesRepository repo;
  late ProduccionesBloc bloc;
  late GoRouter router;

  final cabeceras = [
    ProduccionCabecera(id: 1, fecha: DateTime(2024, 5, 10)),
    ProduccionCabecera(id: 2, fecha: DateTime(2024, 5, 9)),
  ];

  setUp(() {
    repo = FakeApliquesRepository(producciones: cabeceras);
  });

  Future<void> montar(WidgetTester tester) async {
    bloc = ProduccionesBloc(apliquesRepository: repo, idsucursal: 1);
    addTearDown(bloc.close);
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => BlocProvider.value(
            value: bloc,
            child: const ProduccionesScreen(idsucursal: 1),
          ),
        ),
        GoRoute(
          path: '/fabricacion/registro/:idsucursal',
          builder: (_, __) => const Scaffold(body: Text('STUB REGISTRO')),
        ),
        GoRoute(
          path: '/fabricacion/detalle/:idproduccion',
          builder: (_, __) => const Scaffold(body: Text('STUB DETALLE')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra una card por fecha y el botón + en el AppBar',
      (tester) async {
    await montar(tester);

    expect(find.text('10-5-2024'), findsOneWidget);
    expect(find.text('9-5-2024'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(repo.getProduccionesCalls, 1);
  });

  testWidgets('el botón + navega al registro y recarga al volver',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('STUB REGISTRO'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('10-5-2024'), findsOneWidget);
    expect(repo.getProduccionesCalls, 2);
  });

  testWidgets('tap en una fecha navega al detalle y recarga al volver',
      (tester) async {
    await montar(tester);

    await tester.tap(find.text('10-5-2024'));
    await tester.pumpAndSettle();
    expect(find.text('STUB DETALLE'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('10-5-2024'), findsOneWidget);
    expect(repo.getProduccionesCalls, 2);
  });
}
