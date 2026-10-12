import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/config/theme/app_theme.dart';

/// Teléfono de referencia (Pixel 7, en dp), el mismo de las capturas.
const telefono = Size(412, 915);

/// Pantalla en la que se mide el contraste (ver [montarPantalla]).
const _pantallaAncha = Size(1080, 2400);

/// La fuente de prueba de flutter_tester: cualquier familia que no se cargó
/// con FontLoader (Roboto y MaterialIcons sí, en flutter_test_config.dart)
/// se dibuja con ella.
const _fuenteDePrueba = 'FlutterTest';

/// Las guías de accesibilidad de flutter_test que cumple cada pantalla.
enum Guia {
  tapAndroid(
      'lo tocable mide al menos 48x48 (Android)', androidTapTargetGuideline),
  tapIos('lo tocable mide al menos 44x44 (iOS)', iOSTapTargetGuideline),
  etiquetas('lo tocable tiene etiqueta para lectores de pantalla',
      labeledTapTargetGuideline),
  contraste(
      'el texto tiene contraste suficiente (WCAG)', textContrastGuideline);

  const Guia(this.descripcion, this.guia);

  final String descripcion;
  final AccessibilityGuideline guia;
}

/// Si el test en curso mide el contraste: lo fija [verificarGuias] y lo lee
/// [montarPantalla].
bool _midiendoContraste = false;

/// Monta [pantalla] como en la app real (AppTheme, español, GoRouter) y
/// espera a que termine de dibujarse.
///
/// - Tamaños de toque y etiquetas: en un teléfono de 412x915 dp con Roboto
///   (como las capturas golden), para que las medidas sean las del celular.
/// - Contraste: con la fuente de prueba, cuyos glifos son bloques sólidos del
///   color del texto. `textContrastGuideline` toma una captura a 1 px por dp
///   y usa el color más frecuente: con el antialiasing de Roboto (trazos de
///   ~1 px) un texto negro mide gris y daría falsos positivos. Como esa
///   fuente es más ancha que Roboto y a 412 dp desborda en varias pantallas,
///   se mide en una pantalla ancha (el contraste no depende del ancho).
///
/// [rutas] agrega rutas stub por si la pantalla necesita navegar.
Future<void> montarPantalla(
  WidgetTester tester,
  Widget pantalla, {
  List<RouteBase> rutas = const [],
}) async {
  tester.view.physicalSize = _midiendoContraste ? _pantallaAncha : telefono;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => pantalla),
      ...rutas,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: _midiendoContraste ? _temaConFuenteDePrueba() : _temaConRoboto(),
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
    ),
  );
  await tester.pumpAndSettle();
}

/// AppTheme con Roboto también en los estilos que no la heredan de la
/// tipografía (título del AppBar y FilledButton): en el celular toman la
/// fuente del sistema, que es Roboto.
ThemeData _temaConRoboto() {
  final tema = AppTheme().getTheme();
  final boton = tema.filledButtonTheme.style;
  return tema.copyWith(
    appBarTheme: tema.appBarTheme.copyWith(
      titleTextStyle:
          tema.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'Roboto'),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: boton?.copyWith(
        textStyle: WidgetStateProperty.resolveWith(
          (estados) =>
              boton.textStyle?.resolve(estados)?.copyWith(fontFamily: 'Roboto'),
        ),
      ),
    ),
  );
}

/// AppTheme con la fuente de prueba en toda la tipografía.
ThemeData _temaConFuenteDePrueba() {
  final tema = AppTheme().getTheme();
  return tema.copyWith(
    textTheme: tema.textTheme.apply(fontFamily: _fuenteDePrueba),
    primaryTextTheme: tema.primaryTextTheme.apply(fontFamily: _fuenteDePrueba),
  );
}

/// Un test por cada [Guia] sobre la pantalla que deja [montar] (que monta con
/// [montarPantalla]), así el reporte dice cuál falla.
///
/// [omitidas] son las guías que la pantalla todavía no cumple por un bug
/// visual conocido: salen como omitidas (`skip`) y llevan arriba un
/// comentario `// bug: archivo:línea — qué pasa`.
void verificarGuias(
  String estado,
  Future<void> Function(WidgetTester tester) montar, {
  Set<Guia> omitidas = const {},
}) {
  for (final guia in Guia.values) {
    testWidgets(
      '$estado: ${guia.descripcion}',
      (tester) async {
        _midiendoContraste = guia == Guia.contraste;
        addTearDown(() => _midiendoContraste = false);
        final handle = tester.ensureSemantics();
        await montar(tester);

        await expectLater(tester, meetsGuideline(guia.guia));
        handle.dispose();
      },
      skip: omitidas.contains(guia),
    );
  }
}
