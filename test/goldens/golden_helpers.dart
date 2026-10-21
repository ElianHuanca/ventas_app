import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/config/theme/app_theme.dart';

/// Teléfono de referencia de las capturas (Pixel 7, en dp).
const telefono = Size(412, 915);

/// Android de gama baja (360×640 dp): el más chico que se sigue vendiendo.
const telefonoChico = Size(360, 640);

/// La opción "Grande" del tamaño de letra de Android.
const letraGrande = 1.3;

/// Monta [pantalla] como en la app real (tema, español, GoRouter) en un
/// teléfono de [tamano] dp y espera a que termine de dibujarse.
///
/// [escalaTexto] es el tamaño de letra del sistema (`null` = el normal, 1.0).
/// Se fija en el PlatformDispatcher, de donde lo toma el MediaQuery del
/// MaterialApp como en el celular: la app no lo sobrescribe.
///
/// [rutas] agrega rutas stub por si la captura necesita navegar. Con
/// [asentar] en `false` solo hace un `pump` (para capturar un loader, cuya
/// animación infinita nunca deja asentar a `pumpAndSettle`).
Future<void> montarParaCaptura(
  WidgetTester tester,
  Widget pantalla, {
  Size tamano = telefono,
  double? escalaTexto,
  List<RouteBase> rutas = const [],
  bool asentar = true,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  if (escalaTexto != null) {
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
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
      theme: _temaDeCaptura(),
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
  if (asentar) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Fuente para los glifos que Roboto no tiene (la carga flutter_test_config).
const _respaldo = ['Arial'];

/// AppTheme con Roboto en los estilos que no la heredan de la tipografía
/// (título del AppBar y FilledButton): en el celular toman la fuente del
/// sistema, que es Roboto; en flutter_tester saldrían con la de prueba. Y con
/// [_respaldo] para los símbolos que faltan en Roboto.
ThemeData _temaDeCaptura() {
  final tema = AppTheme().getTheme();
  final boton = tema.filledButtonTheme.style;
  return tema.copyWith(
    textTheme: tema.textTheme.apply(fontFamilyFallback: _respaldo),
    primaryTextTheme:
        tema.primaryTextTheme.apply(fontFamilyFallback: _respaldo),
    appBarTheme: tema.appBarTheme.copyWith(
      titleTextStyle: tema.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: 'Roboto',
        fontFamilyFallback: _respaldo,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: boton?.copyWith(
        textStyle: WidgetStateProperty.resolveWith(
          (estados) => boton.textStyle?.resolve(estados)?.copyWith(
                fontFamily: 'Roboto',
                fontFamilyFallback: _respaldo,
              ),
        ),
      ),
    ),
  );
}

/// Compara la pantalla completa (diálogos y snackbars incluidos) con
/// `goldens/<nombre>.png`, relativo al archivo de test que la llama.
Future<void> compararCaptura(String nombre) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$nombre.png'),
    );
