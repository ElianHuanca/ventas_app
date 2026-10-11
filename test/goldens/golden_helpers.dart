import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/config/theme/app_theme.dart';

/// Teléfono de referencia de las capturas (Pixel 7, en dp).
const telefono = Size(412, 915);

/// Monta [pantalla] como en la app real (tema, español, GoRouter) en un
/// teléfono de [tamano] dp y espera a que termine de dibujarse.
///
/// [rutas] agrega rutas stub por si la captura necesita navegar. Con
/// [asentar] en `false` solo hace un `pump` (para capturar un loader, cuya
/// animación infinita nunca deja asentar a `pumpAndSettle`).
Future<void> montarParaCaptura(
  WidgetTester tester,
  Widget pantalla, {
  Size tamano = telefono,
  List<RouteBase> rutas = const [],
  bool asentar = true,
}) async {
  tester.view.physicalSize = tamano;
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

/// AppTheme con Roboto en los estilos que no la heredan de la tipografía
/// (título del AppBar y FilledButton). En el celular toman la fuente del
/// sistema, que es Roboto; en flutter_tester saldrían con la de prueba.
ThemeData _temaDeCaptura() {
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
          (estados) => boton.textStyle
              ?.resolve(estados)
              ?.copyWith(fontFamily: 'Roboto'),
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
