import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/colores/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/colores/presentation/screens/screens.dart';

import '../../../../helpers/fake_repositories.dart';

/// Cuenta las cargas del listado para verificar la recarga al volver.
class _Repo extends FakeColoresRepository {
  _Repo({super.colores});

  int getColoresCalls = 0;

  @override
  Future<List<ColorItem>> getColores({bool soloActivos = true}) {
    getColoresCalls++;
    return super.getColores(soloActivos: soloActivos);
  }
}

void main() {
  late _Repo repo;
  late ColoresBloc bloc;
  late GoRouter router;

  const colores = [
    ColorItem(id: 5, nombre: 'Coral', hex: 'FF7F50'),
    ColorItem(id: 6, nombre: 'Azul marino', hex: '000080'),
  ];

  setUp(() {
    repo = _Repo(colores: colores);
  });

  Future<void> montar(WidgetTester tester) async {
    bloc = ColoresBloc(coloresRepository: repo);
    addTearDown(bloc.close);
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) =>
              BlocProvider.value(value: bloc, child: const ColoresScreen()),
        ),
        GoRoute(
          path: '/color/:idcolor',
          builder: (_, state) => Scaffold(
              body: Text('STUB COLOR ${state.pathParameters['idcolor']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('lista cada color con su nombre, su hex y la muestra',
      (tester) async {
    await montar(tester);

    expect(find.text('Colores'), findsOneWidget);
    expect(find.text('Coral'), findsOneWidget);
    expect(find.text('#FF7F50'), findsOneWidget);
    expect(find.text('Azul marino'), findsOneWidget);
    expect(find.text('#000080'), findsOneWidget);

    final muestra = tester.widget<CircleAvatar>(find.descendant(
      of: find.widgetWithText(ListTile, 'Coral'),
      matching: find.byType(CircleAvatar),
    ));
    expect(muestra.backgroundColor, const Color(0xFFFF7F50));
  });

  testWidgets('sin colores muestra el mensaje de lista vacía', (tester) async {
    repo.colores = const [];
    await montar(tester);

    expect(find.text('No hay colores registrados'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('el botón + navega a /color/0 y recarga al volver',
      (tester) async {
    await montar(tester);
    expect(repo.getColoresCalls, 1);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('STUB COLOR 0'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('Coral'), findsOneWidget);
    expect(repo.getColoresCalls, 2);
  });

  testWidgets('tocar un color navega a /color/:id y recarga al volver',
      (tester) async {
    await montar(tester);

    await tester.tap(find.text('Azul marino'));
    await tester.pumpAndSettle();
    expect(find.text('STUB COLOR 6'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('Azul marino'), findsOneWidget);
    expect(repo.getColoresCalls, 2);
  });
}
