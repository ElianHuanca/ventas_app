import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:textiles_app/config/config.dart';
import 'package:textiles_app/main.dart';

/// Usuario que los tests crean (si no existe) en el Supabase local.
const emailPrueba =
    String.fromEnvironment('IT_EMAIL', defaultValue: 'integracion@example.com');
const passwordPrueba = String.fromEnvironment('IT_PASSWORD',
    defaultValue: 'integracion-local-123');

const snackOk = 'Realizado correctamente';

/// Inicializa Supabase **solo si apunta a la base local** y deja listo el
/// usuario de prueba. Los tests escriben datos reales: contra producción
/// cortan acá, antes de abrir ninguna conexión.
Future<void> prepararBaseLocal() async {
  if (!SupabaseConfig.isLocal) {
    throw StateError(
      'Los tests de integración escriben en la base y solo corren contra el '
      'Supabase local. Correr con --dart-define-from-file=env/local.json '
      '(URL actual: ${SupabaseConfig.url}).',
    );
  }
  await SupabaseConfig.init();
  await _asegurarUsuarioDePrueba();
  await cerrarSesionDirecto();
}

Future<void> _asegurarUsuarioDePrueba() async {
  final auth = SupabaseConfig.client.auth;
  try {
    await auth.signInWithPassword(email: emailPrueba, password: passwordPrueba);
  } on AuthException {
    // Primera corrida contra esta base (o después de un `db reset`). El
    // registro público solo está habilitado en el Supabase local (config.toml).
    await auth.signUp(email: emailPrueba, password: passwordPrueba);
  }
}

Future<void> iniciarSesionDirecto() => SupabaseConfig.client.auth
    .signInWithPassword(email: emailPrueba, password: passwordPrueba);

Future<void> cerrarSesionDirecto() => SupabaseConfig.client.auth.signOut();

/// Sufijo para que cada corrida cree nombres nuevos: la base no permite
/// borrar físicamente sucursales ni telas, así que los datos de prueba quedan
/// (se limpian con `npx supabase@latest db reset`).
/// En base 36 (8 caracteres) para que los nombres no sean mucho más largos
/// que los reales.
String sufijoUnico() => DateTime.now().millisecondsSinceEpoch.toRadixString(36);

Future<void> montarApp(WidgetTester tester) async {
  await tester.pumpWidget(const HuantexApp());
  await tester.pumpAndSettle();
}

/// Bombea frames (en tiempo real) hasta que aparezca [finder]. Hace falta
/// porque las respuestas de Supabase no son frames: `pumpAndSettle` puede
/// volver antes de que lleguen.
Future<void> esperarHasta(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final limite = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(limite)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  final enPantalla = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .join(' | ');
  throw TestFailure('No apareció a tiempo: $finder\nEn pantalla: $enPantalla');
}

/// Desplaza la pantalla actual hasta [finder] (las grillas y listas son
/// perezosas: lo que está fuera de vista no existe todavía) y lo toca.
Future<void> tocar(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Toca [finder] en la lista hasta que aparezca [destino]. Al volver de un
/// formulario la lista se recarga (pasa por el loader) y un toque que cae en
/// ese momento se pierde sin error.
Future<void> tocarHasta(
    WidgetTester tester, Finder finder, Finder destino) async {
  for (var intento = 1;; intento++) {
    await tester.scrollUntilVisible(finder, 200,
        scrollable: listaVertical.first);
    await tester.tap(finder);
    try {
      await esperarHasta(tester, destino, timeout: const Duration(seconds: 5));
      return;
    } on TestFailure {
      if (intento == 3) rethrow;
    }
  }
}

/// En el celular el teclado queda abierto después de `enterText` y puede
/// tapar el botón que sigue.
Future<void> ocultarTeclado(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

/// Enfoca el campo, escribe y cierra el teclado. Volver a escribir en un campo
/// sin enfocarlo antes (después de `ocultarTeclado`) se pierde en silencio:
/// la conexión con el teclado ya está cerrada.
Future<void> escribir(WidgetTester tester, Finder finder, String texto) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, texto);
  await ocultarTeclado(tester);
}

/// Abre el menú lateral. Espera a que termine cualquier transición: durante
/// ella conviven dos pantallas y la que sale (p. ej. /login) no tiene menú.
Future<void> abrirMenu(WidgetTester tester) async {
  await tester.pumpAndSettle();
  tester
      .stateList<ScaffoldState>(find.byType(Scaffold))
      .firstWhere((s) => s.hasDrawer)
      .openDrawer();
  await tester.pumpAndSettle();
}

/// Opción del menú lateral abierto. "Telas" y "Apliques" están dos veces: la
/// gestión y, al pie, el submenú "Dashboard" (ese, con [opcionDelDashboard]).
Finder opcionDelMenu(String opcion) => find
    .descendant(of: find.byType(NavigationDrawer), matching: find.text(opcion))
    .first;

/// Opción [linea] ("Telas" o "Apliques") del submenú "Dashboard".
Finder opcionDelDashboard(String linea) => find
    .descendant(of: find.byType(NavigationDrawer), matching: find.text(linea))
    .last;

Future<void> irDesdeMenu(WidgetTester tester, String opcion) =>
    tocarEnMenu(tester, opcionDelMenu(opcion));

/// Abre el dashboard de [linea] ("Telas" o "Apliques").
Future<void> irAlDashboard(WidgetTester tester, String linea) =>
    tocarEnMenu(tester, opcionDelDashboard(linea));

/// Abre el menú y toca [opcion].
Future<void> tocarEnMenu(WidgetTester tester, Finder opcion) async {
  await abrirMenu(tester);
  // El submenú del dashboard queda al pie: en un celular chico hay que bajar
  await tester.ensureVisible(opcion);
  await tester.pumpAndSettle();
  await tester.tap(opcion);
  await tester.pumpAndSettle();
}

/// Las tarjetas de las grillas (`ItemDashboard`) muestran el título en
/// mayúsculas.
Finder tarjeta(String titulo) => find.text(titulo.toUpperCase());

/// Un `Text` con ese contenido, sin contar los campos de texto que lo tengan
/// escrito (`find.text` también encuentra `EditableText`).
Finder textoFijo(String texto) =>
    find.byWidgetPredicate((w) => w is Text && w.data == texto);

Finder campo(String etiqueta) => find.widgetWithText(TextFormField, etiqueta);

/// Opción de un `DropdownMenu` abierto cuyo texto contiene [texto] (las de
/// color dicen "Rojo (stock: 5.0)").
Finder opcionDeMenu(String texto) => find.ancestor(
    of: find.textContaining(texto), matching: find.byType(MenuItemButton));

/// Abre el [menu] y elige la opción que contiene [texto].
Future<void> elegir(WidgetTester tester, Finder menu, String texto) async {
  await tester.tap(menu);
  await tester.pumpAndSettle();
  final opcion = opcionDeMenu(texto).last;
  await tester.ensureVisible(opcion);
  await tester.pumpAndSettle();
  await tester.tap(opcion);
  await tester.pumpAndSettle();
}

/// Campos de texto del selector de fecha abierto (uno; dos en el de rango).
Finder get _camposDelSelector =>
    find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));

/// Pasa el selector de fecha abierto al modo texto (más estable que tocar el
/// día en el calendario, que depende del mes visible) y devuelve los textos
/// del idioma en que quedó la app: sin `locale` explícito sigue al del
/// dispositivo, que puede estar en inglés.
Future<MaterialLocalizations> _selectorEnModoTexto(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  return MaterialLocalizations.of(tester.element(_camposDelSelector.first));
}

/// En un `showDatePicker` abierto, escribe [fecha] y acepta.
Future<void> elegirFecha(WidgetTester tester, DateTime fecha) async {
  final textos = await _selectorEnModoTexto(tester);
  await tester.enterText(_camposDelSelector, textos.formatCompactDate(fecha));
  await tester.pumpAndSettle();
  await tester.tap(find.text(textos.okButtonLabel));
  await tester.pumpAndSettle();
}

/// En un `showDateRangePicker` abierto, escribe el rango y acepta.
Future<void> elegirRango(
    WidgetTester tester, DateTime desde, DateTime hasta) async {
  final textos = await _selectorEnModoTexto(tester);
  await tester.enterText(
      _camposDelSelector.first, textos.formatCompactDate(desde));
  await tester.enterText(
      _camposDelSelector.last, textos.formatCompactDate(hasta));
  await tester.pumpAndSettle();
  await tester.tap(find.text(textos.okButtonLabel));
  await tester.pumpAndSettle();
}

/// Lista vertical de la pantalla (las grillas y `ListView` de `Screen1`, la
/// lista del dashboard).
Finder get listaVertical => find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down);

/// Botón "atrás" de la `AppBar` de la pantalla de arriba.
Future<void> volver(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton).last);
  await tester.pumpAndSettle();
}

/// Espera a que la base refleje un cambio que la UI guarda sin avisar
/// (p. ej. los switches de colores y disponibilidad).
Future<void> esperarQue(
  Future<bool> Function() condicion, {
  String descripcion = 'condición en la base',
  Duration timeout = const Duration(seconds: 15),
}) async {
  final limite = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(limite)) {
    if (await condicion()) return;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  throw TestFailure('No se cumplió a tiempo: $descripcion');
}
