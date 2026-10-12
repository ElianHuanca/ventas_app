import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/telas/presentation/screens/screens.dart';

import '../../../../helpers/fake_repositories.dart';

/// Cuenta las cargas del listado y permite demorarlas (con el fake al
/// instante el loader nunca llega a dibujarse).
class _Repo extends FakeTelasRepository {
  _Repo({super.telas});

  int getTelasCalls = 0;
  Duration? demora;

  @override
  Future<List<Tela>> getTelas({bool soloActivos = true}) async {
    getTelasCalls++;
    if (demora != null) await Future<void>.delayed(demora!);
    return super.getTelas(soloActivos: soloActivos);
  }
}

void main() {
  late _Repo repo;
  late TelasBloc bloc;
  late GoRouter router;

  final telas = [
    Tela(
      id: 1,
      nombre: 'Lino',
      precxmen: 10,
      precxmay: 8,
      precxrollo: 300,
      precxcompra: 6,
    ),
    Tela(
      id: 2,
      nombre: 'Seda',
      precxmen: 25,
      precxmay: 20,
      precxrollo: 700,
      precxcompra: 15,
      activo: false,
    ),
    Tela(
      id: 3,
      nombre: 'Lino Rústico',
      precxmen: 12,
      precxmay: 9,
      precxrollo: 350,
      precxcompra: 7,
    ),
  ];

  setUp(() {
    repo = _Repo(telas: telas);
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    bloc = TelasBloc(telasRepository: repo);
    addTearDown(bloc.close);
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) =>
              BlocProvider.value(value: bloc, child: const TelasScreen()),
        ),
        GoRoute(
          path: '/tela/:idtela',
          builder: (_, state) => Scaffold(
              body: Text('STUB TELA ${state.pathParameters['idtela']}')),
        ),
        GoRoute(
          path: '/tela-colores/:idtela',
          builder: (_, state) => Scaffold(
              body: Text('STUB COLORES ${state.pathParameters['idtela']}')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  /// Un botón (por texto) dentro de la tarjeta de la tela [nombre].
  Finder enTarjeta(String nombre, String boton) => find.descendant(
        of: find
            .ancestor(
              of: find.text(nombre),
              matching: find
                  .byWidgetPredicate((w) => w is Container && w.margin != null),
            )
            .first,
        matching: find.text(boton),
      );

  String textoBusqueda(WidgetTester tester) => tester
      .widget<EditableText>(find.descendant(
        of: find.byType(TextField),
        matching: find.byType(EditableText),
      ))
      .controller
      .text;

  group('listado', () {
    testWidgets('muestra todas las telas (también inactivas) con sus precios',
        (tester) async {
      await montar(tester);

      expect(find.text('Telas'), findsOneWidget);
      // Gestión: el listado pide también las inactivas
      expect(repo.lastSoloActivos, false);
      expect(find.text('Lino'), findsOneWidget);
      expect(find.text('Seda'), findsOneWidget);
      expect(find.text('Lino Rústico'), findsOneWidget);
      expect(find.text('X Menor: 10.0 Bs'), findsOneWidget);
      expect(find.text('X Mayor: 8.0 Bs'), findsOneWidget);
      expect(find.text('X Rollo: 300.0 Bs'), findsOneWidget);
      expect(find.text('Compra: 6.0 Bs'), findsOneWidget);
      expect(find.text('Modificar'), findsNWidgets(3));
      expect(find.text('Colores'), findsNWidgets(3));
    });

    testWidgets('las inactivas llevan el chip "Inactivo" y el nombre atenuado',
        (tester) async {
      await montar(tester);

      expect(find.text('Inactivo'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(enTarjeta('Seda', 'Inactivo'), findsOneWidget);
      expect(enTarjeta('Lino', 'Inactivo'), findsNothing);

      final inactiva = tester.widget<Text>(find.text('Seda'));
      final activa = tester.widget<Text>(find.text('Lino'));
      expect(inactiva.style!.color, Colors.black38);
      expect(activa.style!.color, Colors.black87);
    });

    testWidgets('sin telas muestra el mensaje de lista vacía', (tester) async {
      repo.telas = const [];
      await montar(tester);

      expect(find.text('No hay telas registradas'), findsOneWidget);
      expect(find.text('Modificar'), findsNothing);
    });
  });

  group('búsqueda', () {
    testWidgets('filtra por nombre sin distinguir mayúsculas', (tester) async {
      await montar(tester);

      await tester.enterText(find.byType(TextField), 'LINO');
      await tester.pump();

      expect(find.text('Lino'), findsOneWidget);
      expect(find.text('Lino Rústico'), findsOneWidget);
      expect(find.text('Seda'), findsNothing);

      await tester.enterText(find.byType(TextField), 'rúst');
      await tester.pump();

      expect(find.text('Lino Rústico'), findsOneWidget);
      expect(find.text('Lino'), findsNothing);
    });

    testWidgets('sin coincidencias avisa que no hay resultados',
        (tester) async {
      await montar(tester);

      await tester.enterText(find.byType(TextField), 'algodón');
      await tester.pump();

      expect(find.text('Sin resultados para esa búsqueda'), findsOneWidget);
      expect(find.text('Lino'), findsNothing);
      expect(find.text('No hay telas registradas'), findsNothing);
    });

    testWidgets('al volver de editar, el campo y el filtro siguen coherentes',
        (tester) async {
      await montar(tester);
      await tester.enterText(find.byType(TextField), 'seda');
      await tester.pump();

      await tester.tap(enTarjeta('Seda', 'Modificar'));
      await tester.pumpAndSettle();
      expect(find.text('STUB TELA 2'), findsOneWidget);

      // La recarga al volver tarda (como contra Supabase): se ve el loader
      repo.demora = const Duration(milliseconds: 300);
      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Lo que dice el campo tiene que coincidir con lo que se filtra
      expect(textoBusqueda(tester), 'seda');
      expect(find.text('Seda'), findsOneWidget);
      expect(find.text('Lino'), findsNothing);
    });
  });

  group('navegación', () {
    testWidgets('el botón + navega a /tela/0 y recarga al volver',
        (tester) async {
      await montar(tester);
      expect(repo.getTelasCalls, 1);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('STUB TELA 0'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('Lino'), findsOneWidget);
      expect(repo.getTelasCalls, 2);
    });

    testWidgets('"Modificar" navega a /tela/:id y recarga al volver',
        (tester) async {
      await montar(tester);

      await tester.tap(enTarjeta('Seda', 'Modificar'));
      await tester.pumpAndSettle();
      expect(find.text('STUB TELA 2'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('Seda'), findsOneWidget);
      expect(repo.getTelasCalls, 2);
    });

    testWidgets('"Colores" navega a /tela-colores/:id sin recargar al volver',
        (tester) async {
      await montar(tester);

      await tester.tap(enTarjeta('Lino Rústico', 'Colores'));
      await tester.pumpAndSettle();
      expect(find.text('STUB COLORES 3'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('Lino Rústico'), findsOneWidget);
      expect(repo.getTelasCalls, 1);
    });
  });
}
