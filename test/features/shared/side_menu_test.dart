import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/auth/auth.dart';
import 'package:textiles_app/features/shared/widgets/menu_index_cubit.dart';
import 'package:textiles_app/features/shared/widgets/side_menu.dart';

import '../../helpers/fake_repositories.dart';

void main() {
  late FakeAuthRepository auth;
  late MenuIndexCubit menuCubit;
  late GoRouter router;

  /// (texto de la sección, ruta) en el orden del menú.
  const secciones = [
    ('Venta telas', '/'),
    ('Venta apliques', '/venta-apliques'),
    ('Fabricación', '/fabricacion'),
    ('Inventario', '/inventario'),
    ('Sucursales', '/sucursales'),
    ('Telas', '/telas'),
    ('Apliques', '/apliques'),
    ('Colores', '/colores'),
    // Submenú "Dashboard"
    ('Telas', '/dashboard/telas'),
    ('Apliques', '/dashboard/apliques'),
  ];

  setUp(() async {
    auth = FakeAuthRepository();
    await auth.iniciarSesion(
      email: FakeAuthRepository.emailOk,
      password: FakeAuthRepository.passwordOk,
    );
  });

  /// Página stub con el menú como drawer, como las pantallas raíz (Screen1).
  Widget pagina(String ruta) => Scaffold(
        appBar: AppBar(),
        drawer: const SideMenu(),
        body: Text('STUB $ruta'),
      );

  /// Arranca en una ruta que no es ninguna sección, para que tocar
  /// cualquiera (incluida "/") sea una navegación real.
  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    menuCubit = MenuIndexCubit();
    addTearDown(menuCubit.close);
    router = GoRouter(
      initialLocation: '/inicio-test',
      routes: [
        GoRoute(
            path: '/inicio-test', builder: (_, __) => pagina('/inicio-test')),
        for (final (_, ruta) in secciones)
          GoRoute(path: ruta, builder: (_, __) => pagina(ruta)),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(RepositoryProvider<AuthRepository>.value(
      value: auth,
      child: BlocProvider.value(
        value: menuCubit,
        child: MaterialApp.router(routerConfig: router),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> abrirMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
  }

  /// "Telas" y "Apliques" están dos veces (gestión y dashboard): se toca el
  /// destino por su posición.
  Finder destino(int i) => find.byType(NavigationDrawerDestination).at(i);

  testWidgets('muestra el título y las 10 secciones en orden', (tester) async {
    await montar(tester);
    await abrirMenu(tester);

    expect(find.text('Menú'), findsOneWidget);
    expect(find.byType(NavigationDrawerDestination), findsNWidgets(10));
    final textos = tester
        .widgetList<NavigationDrawerDestination>(
            find.byType(NavigationDrawerDestination))
        .map((d) => (d.label as Text).data)
        .toList();
    expect(textos, secciones.map((s) => s.$1).toList());
  });

  testWidgets(
      'el dashboard es un submenú: Telas y Apliques bajo el título '
      '"Dashboard"', (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(tester);
    await abrirMenu(tester);

    final titulo = tester.getTopLeft(find.text('Dashboard')).dy;
    expect(tester.getTopLeft(destino(7)).dy, lessThan(titulo),
        reason: 'Colores queda arriba del título');
    expect(tester.getTopLeft(destino(8)).dy, greaterThan(titulo));
    expect(tester.getTopLeft(destino(9)).dy, greaterThan(titulo));
    // El lector de pantalla no ve el título al tocar: los anuncia completos
    // (el destino agrega "pestaña N de M" a la etiqueta)
    expect(find.bySemanticsLabel(RegExp('^Dashboard telas\\b')),
        findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Dashboard apliques\\b')),
        findsOneWidget);
    // Antes de que termine el test: si no, flutter_test lo da por no liberado
    semantica.dispose();
  });

  testWidgets('muestra "Cerrar sesión" con el email de la cuenta',
      (tester) async {
    await montar(tester);
    await abrirMenu(tester);

    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(find.text(FakeAuthRepository.emailOk), findsOneWidget);
  });

  testWidgets('sin email de cuenta el subtítulo queda vacío', (tester) async {
    await auth.cerrarSesion();
    await montar(tester);
    await abrirMenu(tester);

    final tile =
        tester.widget<ListTile>(find.widgetWithText(ListTile, 'Cerrar sesión'));
    expect((tile.subtitle as Text).data, '');
  });

  testWidgets('marca como seleccionada la sección del MenuIndexCubit',
      (tester) async {
    await montar(tester);
    menuCubit.setIndex(3);
    await abrirMenu(tester);

    final drawer =
        tester.widget<NavigationDrawer>(find.byType(NavigationDrawer));
    expect(drawer.selectedIndex, 3);
  });

  for (final (i, (texto, ruta)) in secciones.indexed) {
    testWidgets(
        'tocar "$texto" navega a $ruta, guarda el índice $i '
        'y cierra el menú', (tester) async {
      await montar(tester);
      await abrirMenu(tester);

      await tester.tap(destino(i));
      await tester.pumpAndSettle();

      expect(find.text('STUB $ruta'), findsOneWidget);
      expect(find.text('STUB /inicio-test'), findsNothing);
      expect(menuCubit.state.index, i);
      expect(find.byType(NavigationDrawer), findsNothing);
    });
  }

  testWidgets('"Cerrar sesión" cierra la sesión de la cuenta', (tester) async {
    await montar(tester);
    final cambios = <bool>[];
    final sub = auth.cambiosDeSesion.listen(cambios.add);
    addTearDown(sub.cancel);
    await abrirMenu(tester);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(auth.haySesion, isFalse);
    expect(cambios, [false]);
  });
}
