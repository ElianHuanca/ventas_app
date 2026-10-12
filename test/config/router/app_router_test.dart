import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/config/router/app_router.dart';
import 'package:textiles_app/features/auth/auth.dart';
import 'package:textiles_app/features/shared/widgets/menu_index_cubit.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';

import '../../helpers/fake_repositories.dart';

/// El router real (`createAppRouter`) con su `redirect` por sesión. Solo se
/// montan las rutas que no crean datasources de Supabase (login y las
/// pantallas raíz que leen el `SucursalesBloc` global); el resto se verifica
/// por tabla y por match, sin construir la pantalla. Construirlas todas es
/// tarea de los tests de integración.
void main() {
  /// Las rutas de la tabla "Rutas registradas" del CLAUDE.md.
  const rutasDocumentadas = [
    '/login',
    '/',
    '/venta-apliques',
    '/venta-apliques/:idsucursal',
    '/venta-apliques/registro/:idsucursal',
    '/venta-apliques/detalle/:idventa',
    '/fabricacion',
    '/fabricacion/:idsucursal',
    '/fabricacion/registro/:idsucursal',
    '/fabricacion/detalle/:idproduccion',
    '/sucursales',
    '/sucursal/:idsucursal',
    '/sucursal-disponibilidad/:idsucursal',
    '/telas',
    '/tela/:idtela',
    '/tela-colores/:idtela',
    '/apliques',
    '/aplique/:idaplique',
    '/aplique-colores/:idaplique',
    '/colores',
    '/color/:idcolor',
    '/ventas/:idsucursal',
    '/det_ventas/:idventa',
    '/det_venta/:idsucursal',
    '/dashboard',
  ];

  group('tabla de rutas', () {
    late GoRouter router;

    setUp(() => router = createAppRouter(authRepository: FakeAuthRepository()));
    tearDown(() => router.dispose());

    test('son exactamente las documentadas en el CLAUDE.md', () {
      final rutas = router.configuration.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();

      expect(rutas, unorderedEquals(rutasDocumentadas));
      expect(rutas.toSet(), hasLength(rutas.length), reason: 'sin duplicados');
    });

    // Rutas con el mismo prefijo: el segmento fijo (registro/detalle) no
    // tiene que confundirse con el parámetro.
    const casos = {
      '/venta-apliques/5': ('/venta-apliques/:idsucursal', {'idsucursal': '5'}),
      '/venta-apliques/registro/5': (
        '/venta-apliques/registro/:idsucursal',
        {'idsucursal': '5'}
      ),
      '/venta-apliques/detalle/9?fecha=2026-10-05': (
        '/venta-apliques/detalle/:idventa',
        {'idventa': '9'}
      ),
      '/fabricacion/3': ('/fabricacion/:idsucursal', {'idsucursal': '3'}),
      '/fabricacion/registro/3': (
        '/fabricacion/registro/:idsucursal',
        {'idsucursal': '3'}
      ),
      '/fabricacion/detalle/8': (
        '/fabricacion/detalle/:idproduccion',
        {'idproduccion': '8'}
      ),
      '/sucursal/0': ('/sucursal/:idsucursal', {'idsucursal': '0'}),
      '/sucursal-disponibilidad/2': (
        '/sucursal-disponibilidad/:idsucursal',
        {'idsucursal': '2'}
      ),
      '/tela-colores/4': ('/tela-colores/:idtela', {'idtela': '4'}),
      '/aplique-colores/6': ('/aplique-colores/:idaplique', {'idaplique': '6'}),
      '/det_ventas/11': ('/det_ventas/:idventa', {'idventa': '11'}),
      '/det_venta/1': ('/det_venta/:idsucursal', {'idsucursal': '1'}),
    };

    for (final MapEntry(key: ubicacion, value: (ruta, parametros))
        in casos.entries) {
      test('$ubicacion resuelve a $ruta', () {
        final match = router.configuration.findMatch(ubicacion);

        expect(match.isError, isFalse);
        expect(match.fullPath, ruta);
        expect(match.pathParameters, parametros);
      });
    }

    test('el query de la venta de apliques llega a la ruta de detalle', () {
      final match = router.configuration
          .findMatch('/venta-apliques/detalle/9?fecha=2026-10-05');

      expect(match.uri.queryParameters['fecha'], '2026-10-05');
    });

    test('una ruta inexistente no matchea ninguna', () {
      expect(router.configuration.findMatch('/no-existe').isError, isTrue);
    });
  });

  group('redirect por sesión', () {
    late FakeAuthRepository auth;
    late GoRouter router;

    Future<void> montar(WidgetTester tester, {bool conSesion = false}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      auth = FakeAuthRepository();
      if (conSesion) {
        await auth.iniciarSesion(
          email: FakeAuthRepository.emailOk,
          password: FakeAuthRepository.passwordOk,
        );
      }
      router = createAppRouter(authRepository: auth);
      addTearDown(router.dispose);
      final sucursales = SucursalesBloc(
        sucursalesRepository: FakeSucursalesRepository(
            sucursales: [Sucursal(id: 1, nombre: 'Centro')]),
      );
      addTearDown(sucursales.close);
      final menu = MenuIndexCubit();
      addTearDown(menu.close);

      await tester.pumpWidget(MultiBlocProvider(
        providers: [
          RepositoryProvider<AuthRepository>.value(value: auth),
          BlocProvider.value(value: menu),
          BlocProvider.value(value: sucursales),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    String ubicacion() =>
        router.routerDelegate.currentConfiguration.uri.toString();

    Future<void> ingresarDesdeLogin(WidgetTester tester) async {
      await tester.enterText(
          find.byKey(const Key('login_email')), FakeAuthRepository.emailOk);
      await tester.enterText(find.byKey(const Key('login_password')),
          FakeAuthRepository.passwordOk);
      await tester.pump();
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
    }

    testWidgets('sin sesión abre en /login', (tester) async {
      await montar(tester);

      expect(ubicacion(), '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('sin sesión, un deep link también termina en /login',
        (tester) async {
      await montar(tester);

      for (final destino in ['/sucursales', '/dashboard', '/ventas/1']) {
        router.go(destino);
        await tester.pumpAndSettle();
        expect(ubicacion(), '/login', reason: destino);
      }
    });

    testWidgets('al iniciar sesión el router solo pasa al inicio',
        (tester) async {
      await montar(tester);

      await ingresarDesdeLogin(tester);

      expect(ubicacion(), '/');
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Sucursales'), findsOneWidget);
      expect(find.text('CENTRO'), findsOneWidget);
      // El inicio es la venta de telas: sin la tarjeta de alta
      expect(find.text('AGREGAR SUCURSAL'), findsNothing);
    });

    testWidgets('con sesión, ir a /login vuelve al inicio', (tester) async {
      await montar(tester, conSesion: true);
      expect(ubicacion(), '/');

      router.go('/login');
      await tester.pumpAndSettle();

      expect(ubicacion(), '/');
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('con sesión deja pasar a las rutas raíz', (tester) async {
      await montar(tester, conSesion: true);

      router.go('/sucursales');
      await tester.pumpAndSettle();
      expect(ubicacion(), '/sucursales');
      expect(find.text('AGREGAR SUCURSAL'), findsOneWidget);

      router.go('/venta-apliques');
      await tester.pumpAndSettle();
      expect(ubicacion(), '/venta-apliques');
      expect(find.text('Venta Apliques'), findsOneWidget);

      router.go('/fabricacion');
      await tester.pumpAndSettle();
      expect(ubicacion(), '/fabricacion');
      expect(find.text('Fabricación'), findsOneWidget);
    });

    testWidgets(
        'cerrar sesión desde el menú vuelve a /login sin navegar a mano',
        (tester) async {
      await montar(tester, conSesion: true);
      router.go('/sucursales');
      await tester.pumpAndSettle();

      tester.state<ScaffoldState>(find.byType(Scaffold).last).openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(auth.haySesion, isFalse);
      expect(ubicacion(), '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('si la sesión se cae (expira) el router manda a /login',
        (tester) async {
      await montar(tester, conSesion: true);
      expect(ubicacion(), '/');

      await auth.cerrarSesion();
      await tester.pumpAndSettle();

      expect(ubicacion(), '/login');
    });
  });

  test('dispose() del router deja de escuchar los cambios de sesión', () {
    final cambios = StreamController<bool>.broadcast();
    addTearDown(cambios.close);
    final router =
        createAppRouter(authRepository: _AuthConCambios(cambios.stream));
    expect(cambios.hasListener, isTrue);

    router.dispose();

    expect(cambios.hasListener, isFalse,
        reason: 'el SesionListenable del router quedó suscripto');
  });
}

/// Fake de auth con el stream de sesión a la vista del test.
class _AuthConCambios extends FakeAuthRepository {
  _AuthConCambios(this._cambios);

  final Stream<bool> _cambios;

  @override
  Stream<bool> get cambiosDeSesion => _cambios;
}
