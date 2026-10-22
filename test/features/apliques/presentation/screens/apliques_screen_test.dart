import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';

import '../../../../helpers/fake_repositories.dart';

/// Cuenta las cargas del listado y permite demorarlas (con el fake al
/// instante el loader nunca llega a dibujarse).
class _Repo extends FakeApliquesRepository {
  _Repo({super.apliques});

  int getApliquesCalls = 0;
  Duration? demora;

  @override
  Future<List<Aplique>> getApliques({bool soloActivos = true}) async {
    getApliquesCalls++;
    if (demora != null) await Future<void>.delayed(demora!);
    return super.getApliques(soloActivos: soloActivos);
  }
}

void main() {
  late _Repo repo;
  late ApliquesBloc bloc;
  late GoRouter router;

  final apliques = [
    Aplique(
      id: 1,
      nombre: 'Flor Petalo - Bolsa x100 und',
      costoFabricacion: 12.5,
      anchoCm: 4,
      altoCm: 3,
    ),
    Aplique(id: 2, nombre: 'Luna', costoFabricacion: 8, activo: false),
    Aplique(id: 3, nombre: 'Flor Grande', costoFabricacion: 20, anchoCm: 6),
  ];

  setUp(() {
    repo = _Repo(apliques: apliques);
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    bloc = ApliquesBloc(apliquesRepository: repo);
    addTearDown(bloc.close);
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) =>
              BlocProvider.value(value: bloc, child: const ApliquesScreen()),
        ),
        GoRoute(
          path: '/aplique/:idaplique',
          builder: (_, state) => Scaffold(
              body: Text('STUB APLIQUE ${state.pathParameters['idaplique']}')),
        ),
        GoRoute(
          path: '/aplique-colores/:idaplique',
          builder: (_, state) => Scaffold(
              body: Text('STUB COLORES ${state.pathParameters['idaplique']}')),
        ),
        GoRoute(
          path: '/aplique-fotos/:idaplique',
          builder: (_, state) => Scaffold(
              body: Text('STUB FOTOS ${state.pathParameters['idaplique']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  /// Un texto (chip o botón) dentro de la tarjeta del aplique [nombre].
  Finder enTarjeta(String nombre, String texto) => find.descendant(
        of: find
            .ancestor(
              of: find.text(nombre),
              matching: find
                  .byWidgetPredicate((w) => w is Container && w.margin != null),
            )
            .first,
        matching: find.text(texto),
      );

  /// El lápiz "Modificar" de la tarjeta [nombre].
  Finder lapizDe(String nombre) => find.descendant(
        of: find
            .ancestor(
              of: find.text(nombre),
              matching: find
                  .byWidgetPredicate((w) => w is Container && w.margin != null),
            )
            .first,
        matching: find.byTooltip('Modificar'),
      );

  String textoBusqueda(WidgetTester tester) => tester
      .widget<EditableText>(find.descendant(
        of: find.byType(TextField),
        matching: find.byType(EditableText),
      ))
      .controller
      .text;

  group('listado', () {
    testWidgets('muestra todos los apliques (también inactivos)',
        (tester) async {
      await montar(tester);

      expect(find.text('Apliques'), findsOneWidget);
      // Gestión: el listado pide también los inactivos
      expect(repo.lastSoloActivos, false);
      expect(find.text('Flor Petalo'), findsOneWidget);
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Flor Grande'), findsOneWidget);
      expect(find.byTooltip('Modificar'), findsNWidgets(3));
      expect(find.text('Colores'), findsNWidgets(3));
    });

    testWidgets('muestra medidas, costo y la presentación como chips',
        (tester) async {
      await montar(tester);

      // El sufijo tras " - " va en un chip aparte
      expect(enTarjeta('Flor Petalo', 'Bolsa x100 und'), findsOneWidget);
      expect(enTarjeta('Flor Petalo', '4.0 × 3.0 cm'), findsOneWidget);
      expect(enTarjeta('Flor Petalo', '12.5 Bs'), findsOneWidget);
      // Sin medidas / con una sola medida
      expect(enTarjeta('Luna', 'Sin dimensiones'), findsOneWidget);
      expect(enTarjeta('Flor Grande', '6.0 × ? cm'), findsOneWidget);
      expect(enTarjeta('Flor Grande', '20.0 Bs'), findsOneWidget);
    });

    testWidgets('los inactivos llevan el chip "Inactivo" y el nombre atenuado',
        (tester) async {
      await montar(tester);

      expect(find.text('Inactivo'), findsOneWidget);
      expect(enTarjeta('Luna', 'Inactivo'), findsOneWidget);
      expect(enTarjeta('Flor Grande', 'Inactivo'), findsNothing);

      final inactivo = tester.widget<Text>(find.text('Luna'));
      final activo = tester.widget<Text>(find.text('Flor Grande'));
      expect(inactivo.style!.color, Colors.black38);
      expect(activo.style!.color, Colors.black87);
    });

    testWidgets('sin apliques muestra el mensaje de lista vacía',
        (tester) async {
      repo.apliques = const [];
      await montar(tester);

      expect(find.text('No hay apliques registrados'), findsOneWidget);
      expect(find.byTooltip('Modificar'), findsNothing);
    });
  });

  group('búsqueda', () {
    testWidgets('filtra por nombre sin distinguir mayúsculas', (tester) async {
      await montar(tester);

      await tester.enterText(find.byType(TextField), 'FLOR');
      await tester.pump();

      expect(find.text('Flor Petalo'), findsOneWidget);
      expect(find.text('Flor Grande'), findsOneWidget);
      expect(find.text('Luna'), findsNothing);
    });

    testWidgets('busca también en la presentación del nombre completo',
        (tester) async {
      await montar(tester);

      await tester.enterText(find.byType(TextField), 'bolsa');
      await tester.pump();

      expect(find.text('Flor Petalo'), findsOneWidget);
      expect(find.text('Flor Grande'), findsNothing);
    });

    testWidgets('sin coincidencias avisa que no hay resultados',
        (tester) async {
      await montar(tester);

      await tester.enterText(find.byType(TextField), 'estrella');
      await tester.pump();

      expect(find.text('Sin resultados para esa búsqueda'), findsOneWidget);
      expect(find.text('Luna'), findsNothing);
      expect(find.text('No hay apliques registrados'), findsNothing);
    });

    testWidgets('al volver de editar, el campo y el filtro siguen coherentes',
        (tester) async {
      await montar(tester);
      await tester.enterText(find.byType(TextField), 'luna');
      await tester.pump();

      await tester.tap(lapizDe('Luna'));
      await tester.pumpAndSettle();
      expect(find.text('STUB APLIQUE 2'), findsOneWidget);

      // La recarga al volver tarda (como contra Supabase): se ve el loader
      repo.demora = const Duration(milliseconds: 300);
      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Lo que dice el campo tiene que coincidir con lo que se filtra
      expect(textoBusqueda(tester), 'luna');
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('Flor Grande'), findsNothing);
    });
  });

  group('navegación', () {
    testWidgets('el botón + navega a /aplique/0 y recarga al volver',
        (tester) async {
      await montar(tester);
      expect(repo.getApliquesCalls, 1);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('STUB APLIQUE 0'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('Luna'), findsOneWidget);
      expect(repo.getApliquesCalls, 2);
    });

    testWidgets('tocar la tarjeta también abre /aplique/:id y recarga al volver',
        (tester) async {
      await montar(tester);

      await tester.tap(find.text('Flor Grande'));
      await tester.pumpAndSettle();
      expect(find.text('STUB APLIQUE 3'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(repo.getApliquesCalls, 2);
    });

    testWidgets('"Modificar" navega a /aplique/:id y recarga al volver',
        (tester) async {
      await montar(tester);

      await tester.tap(lapizDe('Flor Grande'));
      await tester.pumpAndSettle();
      expect(find.text('STUB APLIQUE 3'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('Flor Grande'), findsOneWidget);
      expect(repo.getApliquesCalls, 2);
    });

    testWidgets(
        '"Colores" navega a /aplique-colores/:id sin recargar al volver',
        (tester) async {
      await montar(tester);

      await tester.tap(enTarjeta('Flor Petalo', 'Colores'));
      await tester.pumpAndSettle();
      expect(find.text('STUB COLORES 1'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('Flor Petalo'), findsOneWidget);
      expect(repo.getApliquesCalls, 1);
    });

    testWidgets('"Fotos" navega a /aplique-fotos/:id sin recargar al volver',
        (tester) async {
      await montar(tester);

      await tester.tap(enTarjeta('Flor Petalo', 'Fotos'));
      await tester.pumpAndSettle();
      expect(find.text('STUB FOTOS 1'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('Flor Petalo'), findsOneWidget);
      expect(repo.getApliquesCalls, 1);
    });
  });
}
