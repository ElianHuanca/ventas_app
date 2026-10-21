// Utilidades compartidas por los scripts de tool/ que usan el SDK de Android:
// ubicar adb/apksigner, correr comandos, manejar el emulador (instalar, abrir
// la app, logcat) y tocar la UI con uiautomator para iniciar sesión.
// Sin dependencias: solo dart:io.
//
// ⚠️ La app de prueba tiene el mismo applicationId que la oficial: instalarla
// en un celular reemplaza la del negocio. Por eso [Emulador] rechaza todo
// serial que no sea de un emulador.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const appId = 'com.example.textiles_app';
const serialPorDefecto = 'emulator-5554';

/// Raíz del repo: los scripts se corren desde ahí (`dart run tool/...`).
final raiz = Directory.current.path;

/// Error esperable de un script (falta el SDK, el emulador, un archivo...):
/// se muestra el mensaje sin la pila.
class ErrorDeHerramienta implements Exception {
  const ErrorDeHerramienta(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Corre [principal] mostrando un [ErrorDeHerramienta] como mensaje y con
/// código de salida 2 (1 queda para "la verificación falló").
Future<void> correrScript(Future<int> Function() principal) async {
  try {
    exitCode = await principal();
  } on ErrorDeHerramienta catch (e) {
    stderr.writeln('ERROR: $e');
    exitCode = 2;
  }
}

String unir(String a, String b) => '$a${Platform.pathSeparator}$b';

String _ejecutable(String ruta) => Platform.isWindows ? '$ruta.exe' : ruta;

/// SDK de Android: `sdk.dir` de android/local.properties (lo escribe
/// Flutter), ANDROID_HOME, ANDROID_SDK_ROOT o la ubicación por defecto.
String sdkAndroid() {
  final candidatos = <String?>[];
  final local = File(unir(raiz, unir('android', 'local.properties')));
  if (local.existsSync()) {
    for (final linea in local.readAsLinesSync()) {
      if (linea.startsWith('sdk.dir=')) {
        candidatos.add(linea
            .substring('sdk.dir='.length)
            .replaceAll(r'\\', r'\')
            .replaceAll(r'\:', ':'));
      }
    }
  }
  final env = Platform.environment;
  candidatos
    ..add(env['ANDROID_HOME'])
    ..add(env['ANDROID_SDK_ROOT']);
  if (env['LOCALAPPDATA'] != null) {
    candidatos.add(unir(env['LOCALAPPDATA']!, unir('Android', 'Sdk')));
  }
  if (env['HOME'] != null) {
    candidatos
      ..add('${env['HOME']}/Android/Sdk')
      ..add('${env['HOME']}/Library/Android/sdk');
  }
  for (final c in candidatos) {
    if (c != null && c.isNotEmpty && Directory(c).existsSync()) return c;
  }
  throw const ErrorDeHerramienta(
      'No encontré el SDK de Android (definir ANDROID_HOME)');
}

String rutaAdb() {
  final adb = _ejecutable(unir(sdkAndroid(), unir('platform-tools', 'adb')));
  if (!File(adb).existsSync()) {
    throw ErrorDeHerramienta('No está adb en $adb');
  }
  return adb;
}

/// apksigner de la versión más nueva de build-tools que lo tenga.
String rutaApksigner() {
  final dir = Directory(unir(sdkAndroid(), 'build-tools'));
  if (!dir.existsSync()) {
    throw ErrorDeHerramienta('No existe ${dir.path}');
  }
  final nombre = Platform.isWindows ? 'apksigner.bat' : 'apksigner';
  final versiones = dir
      .listSync()
      .whereType<Directory>()
      .where((d) => File(unir(d.path, nombre)).existsSync())
      .toList()
    ..sort((a, b) => _compararVersion(_nombre(b.path), _nombre(a.path)));
  if (versiones.isEmpty) {
    throw ErrorDeHerramienta('No hay $nombre en ${dir.path}/<versión>/');
  }
  return unir(versiones.first.path, nombre);
}

String _nombre(String ruta) => ruta.split(RegExp(r'[\\/]')).last;

/// "36.1.0" > "36.0.0" > "35.0.0-rc1" (las rc van después de la final).
int _compararVersion(String a, String b) {
  List<int> partes(String v) => v
      .split(RegExp(r'[.\-]'))
      .map((p) => int.tryParse(p) ?? -1)
      .toList();
  final pa = partes(a);
  final pb = partes(b);
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
  }
  return pb.length.compareTo(pa.length);
}

/// `flutter` (en Windows es un .bat: necesita la shell).
String get flutter => 'flutter';

/// Corre un comando y devuelve su salida. Los .bat (flutter, apksigner) van
/// por la shell en Windows; adb y git no (así los argumentos no se
/// reinterpretan). Si pasa [limite] lo corta: un `adb` contra un emulador que
/// se cayó (p. ej. la PC sin memoria) se queda esperando para siempre.
Future<ProcessResult> correr(String exe, List<String> args,
    {String? dir, Duration limite = const Duration(minutes: 10)}) async {
  final porShell = Platform.isWindows &&
      (exe == flutter || exe.toLowerCase().endsWith('.bat'));
  final Process proceso;
  try {
    proceso = await Process.start(exe, args,
        workingDirectory: dir, runInShell: porShell);
  } on ProcessException catch (e) {
    throw ErrorDeHerramienta('No se pudo correr $exe: ${e.message}');
  }
  final salida = proceso.stdout.transform(utf8.decoder).join();
  final errores = proceso.stderr.transform(utf8.decoder).join();
  final codigo = await proceso.exitCode.timeout(limite, onTimeout: () {
    proceso.kill();
    // Solo los primeros argumentos: el resto puede ser la contraseña
    // (`input text`)
    throw ErrorDeHerramienta('${_nombre(exe)} ${args.take(3).join(' ')} … no '
        'terminó en ${limite.inSeconds} s (¿se cayó el emulador?)');
  });
  return ProcessResult(proceso.pid, codigo, await salida, await errores);
}

/// Como [correr], pero con la salida a la vista (compilaciones largas).
Future<int> correrVisible(String exe, List<String> args, {String? dir}) async {
  final porShell = Platform.isWindows &&
      (exe == flutter || exe.toLowerCase().endsWith('.bat'));
  final proceso = await Process.start(exe, args,
      workingDirectory: dir,
      runInShell: porShell,
      mode: ProcessStartMode.inheritStdio);
  return proceso.exitCode;
}

void paso(String texto) => stdout.writeln('\n== $texto');
void info(String texto) => stdout.writeln('   $texto');

// ===== Firma =====

/// Certificado oficial (`F:\Elian\claves\huantex-release.jks`, alias
/// huantex, CN=Huantex): SHA-256 del certificado, como lo imprime apksigner.
const sha256Oficial =
    '48e1da98d963f1dddfb0965090b1599a4151cfabc6c5d2999b345d9fc4c47bfb';

class Firmante {
  const Firmante(this.dn, this.sha256);
  final String dn;
  final String sha256;
  bool get esOficial => sha256 == sha256Oficial;
  bool get esDebug => dn.contains('Android Debug');
  String get descripcion => esOficial
      ? 'clave oficial ($dn)'
      : esDebug
          ? 'clave de DEBUG de esta PC ($dn, SHA-256 $sha256)'
          : 'otra clave ($dn, SHA-256 $sha256)';
}

/// Firmantes del APK según `apksigner verify --print-certs`. Falla si la
/// firma no verifica (APK sin firmar, alterado o corrupto).
Future<List<Firmante>> firmantes(String apk) async {
  if (!File(apk).existsSync()) {
    throw ErrorDeHerramienta('No existe el APK $apk');
  }
  final r = await correr(rutaApksigner(), ['verify', '--print-certs', apk]);
  final salida = '${r.stdout}';
  if (r.exitCode != 0) {
    throw ErrorDeHerramienta(
        'apksigner no verifica $apk (¿sin firmar o alterado?):\n$salida${r.stderr}');
  }
  final dns = <int, String>{};
  final shas = <int, String>{};
  final reDn = RegExp(r'^Signer #(\d+) certificate DN: (.*)$', multiLine: true);
  final reSha = RegExp(r'^Signer #(\d+) certificate SHA-256 digest: ([0-9a-f]+)',
      multiLine: true);
  for (final m in reDn.allMatches(salida)) {
    dns[int.parse(m[1]!)] = m[2]!.trim();
  }
  for (final m in reSha.allMatches(salida)) {
    shas[int.parse(m[1]!)] = m[2]!.trim();
  }
  return [
    for (final n in shas.keys.toList()..sort()) Firmante(dns[n] ?? '?', shas[n]!)
  ];
}

// ===== Emulador =====

class Emulador {
  Emulador(this.serial) {
    if (!serial.startsWith('emulator-')) {
      throw ErrorDeHerramienta(
          '$serial no es un emulador. Estos scripts instalan y desinstalan '
          '$appId: en un celular reemplazarían la app oficial del negocio.');
    }
  }

  final String serial;
  late final String _adb = rutaAdb();

  Future<ProcessResult> adb(List<String> args,
      {Duration limite = const Duration(minutes: 2)}) async {
    final r = await correr(_adb, ['-s', serial, ...args], limite: limite);
    final err = '${r.stderr}';
    if (err.contains("device '$serial' not found") ||
        err.contains('device offline')) {
      throw ErrorDeHerramienta('El emulador $serial se desconectó '
          '(¿la PC se quedó sin memoria? ver el log del emulador)');
    }
    return r;
  }

  Future<String> shell(String comando) async {
    final r = await adb(['shell', comando]);
    return '${r.stdout}';
  }

  Future<void> verificarConectado() async {
    final r = await adb(['get-state']);
    if ('${r.stdout}'.trim() != 'device') {
      throw ErrorDeHerramienta('El emulador $serial no está conectado. '
          'Lanzarlo con: emulator -avd Medium_Phone_API_36.1 -no-window '
          '-no-audio -no-boot-anim -no-snapshot-save');
    }
    if ((await shell('getprop sys.boot_completed')).trim() != '1') {
      throw ErrorDeHerramienta('El emulador $serial todavía está arrancando');
    }
  }

  /// Pantalla encendida y sin bloqueo: si se duerme, la app deja de dibujar.
  Future<void> despertar() async {
    await shell('svc power stayon true');
    await shell('input keyevent KEYCODE_WAKEUP');
    await shell('wm dismiss-keyguard');
  }

  Future<String> instalar(String apk, {required bool reemplazar}) async {
    final r = await adb(['install', if (reemplazar) '-r', apk],
        limite: const Duration(minutes: 5));
    final salida = '${r.stdout}${r.stderr}'.trim();
    if (r.exitCode != 0 || !salida.contains('Success')) {
      throw ErrorDeHerramienta('adb install falló:\n$salida');
    }
    return salida;
  }

  Future<void> desinstalar() => adb(['uninstall', appId]);

  Future<bool> instalada() async =>
      (await shell('pm list packages $appId')).contains('package:$appId');

  Future<void> abrirApp() =>
      shell('monkey -p $appId -c android.intent.category.LAUNCHER 1');

  Future<void> cerrarApp() => shell('am force-stop $appId');

  Future<bool> appAlFrente() async {
    final s = await shell('dumpsys activity activities');
    return s
        .split('\n')
        .any((l) => l.contains('topResumedActivity') && l.contains(appId));
  }

  Future<bool> appViva() async => (await shell('pidof $appId')).trim().isNotEmpty;

  Future<void> limpiarLogcat() => adb(['logcat', '-c']);

  Future<String> logcat() async => '${(await adb(['logcat', '-d', '-v', 'threadtime'])).stdout}';

  /// Nodos de la pantalla actual (uiautomator). Flutter publica su árbol de
  /// semántica: los TextField salen como EditText con el label en `hint`.
  Future<List<NodoUi>> ui() async {
    const archivo = '/sdcard/ventas_ui.xml';
    await shell('uiautomator dump $archivo');
    return NodoUi.parsear(await shell('cat $archivo'));
  }

  Future<NodoUi?> esperarNodo(bool Function(NodoUi) condicion,
      {Duration limite = const Duration(seconds: 30)}) async {
    final fin = DateTime.now().add(limite);
    while (DateTime.now().isBefore(fin)) {
      final nodo = (await ui()).where(condicion).firstOrNull;
      if (nodo != null) return nodo;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return null;
  }

  Future<void> tocar(NodoUi nodo) =>
      shell('input tap ${nodo.centroX} ${nodo.centroY}');

  /// Escribe en el campo con foco. `input text` no acepta espacios (van
  /// como %s) y el texto pasa por la shell del emulador: va entre comillas.
  Future<void> escribir(String texto) {
    final escapado = texto.replaceAll("'", r"'\''").replaceAll(' ', '%s');
    return shell("input text '$escapado'");
  }

  Future<void> tecla(String codigo) => shell('input keyevent $codigo');
}

class NodoUi {
  NodoUi(this.texto, this.descripcion, this.pista, this.clase, this.x1,
      this.y1, this.x2, this.y2);

  final String texto;
  final String descripcion;
  final String pista;
  final String clase;
  final int x1, y1, x2, y2;

  int get centroX => (x1 + x2) ~/ 2;
  int get centroY => (y1 + y2) ~/ 2;
  bool get esCampo => clase == 'android.widget.EditText';

  /// Todo lo que se lee del nodo: texto, content-desc y hint.
  String get etiqueta => [texto, descripcion, pista].join(' ');

  static final _reNodo = RegExp(r'<node\b([^>]*)>');
  static final _reAtributo = RegExp(r'([\w-]+)="([^"]*)"');
  static final _reBounds = RegExp(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]');

  static List<NodoUi> parsear(String xml) {
    final nodos = <NodoUi>[];
    for (final m in _reNodo.allMatches(xml)) {
      final atributos = {
        for (final a in _reAtributo.allMatches(m[1]!)) a[1]!: _xml(a[2]!)
      };
      final b = _reBounds.firstMatch(atributos['bounds'] ?? '');
      if (b == null) continue;
      nodos.add(NodoUi(
        atributos['text'] ?? '',
        atributos['content-desc'] ?? '',
        atributos['hint'] ?? '',
        atributos['class'] ?? '',
        int.parse(b[1]!),
        int.parse(b[2]!),
        int.parse(b[3]!),
        int.parse(b[4]!),
      ));
    }
    return nodos;
  }

  static String _xml(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#10;', '\n')
      .replaceAll('&amp;', '&');
}

// ===== Sesión del usuario de prueba =====

/// Usuario de los tests de integración. Las credenciales se leen de
/// integration_test/helpers.dart (o de IT_EMAIL / IT_PASSWORD), para no
/// duplicarlas acá. Nunca se imprimen.
class Credenciales {
  Credenciales._(this.email, this.password);
  final String email;
  final String password;

  factory Credenciales.deIntegracion() {
    final helpers = File(unir(raiz, unir('integration_test', 'helpers.dart')));
    if (!helpers.existsSync()) {
      throw ErrorDeHerramienta('No existe ${helpers.path}');
    }
    final fuente = helpers.readAsStringSync();
    String leer(String constante) {
      final m = RegExp(
              '$constante\\s*=\\s*String\\.fromEnvironment\\(\\s*\'(\\w+)\',\\s*defaultValue:\\s*\'([^\']*)\'')
          .firstMatch(fuente);
      if (m == null) {
        throw ErrorDeHerramienta('No encontré $constante en ${helpers.path}');
      }
      return Platform.environment[m[1]!] ?? m[2]!;
    }

    return Credenciales._(leer('emailPrueba'), leer('passwordPrueba'));
  }
}

/// Lee un --dart-define-from-file (env/*.json).
Map<String, String> leerEnv(String ruta) {
  final archivo = File(ruta);
  if (!archivo.existsSync()) throw ErrorDeHerramienta('No existe $ruta');
  final json = jsonDecode(archivo.readAsStringSync()) as Map<String, dynamic>;
  return json.map((k, v) => MapEntry(k, '$v'));
}

/// Deja creado el usuario de prueba en el Supabase local (como
/// `prepararBaseLocal()` de los tests de integración): si no puede entrar,
/// se registra (el sign-up solo está habilitado en el config.toml local).
/// Usa [envPc] (URL vista desde la PC, p. ej. env/local.json).
Future<void> asegurarUsuario(Credenciales c, String envPc) async {
  final env = leerEnv(envPc);
  final url = env['SUPABASE_URL'] ?? '';
  final clave = env['SUPABASE_KEY'] ?? '';
  final host = Uri.parse(url).host;
  if (host != '127.0.0.1' && host != 'localhost') {
    throw ErrorDeHerramienta(
        '$envPc no apunta al Supabase local ($url): no se crea nada.');
  }
  final cliente = HttpClient();
  try {
    Future<int> post(String ruta, Map<String, String> cuerpo) async {
      final pedido = await cliente.postUrl(Uri.parse('$url$ruta'));
      pedido.headers
        ..set('apikey', clave)
        ..contentType = ContentType.json;
      pedido.write(jsonEncode(cuerpo));
      final respuesta = await pedido.close();
      await respuesta.drain<void>();
      return respuesta.statusCode;
    }

    final datos = {'email': c.email, 'password': c.password};
    try {
      if (await post('/auth/v1/token?grant_type=password', datos) == 200) {
        return;
      }
      final alta = await post('/auth/v1/signup', datos);
      if (alta != 200) {
        throw ErrorDeHerramienta(
            'No se pudo crear el usuario de prueba (HTTP $alta)');
      }
    } on SocketException catch (e) {
      throw ErrorDeHerramienta(
          'El Supabase local no responde en $url (${e.message}). '
          '¿Está levantado? (npx supabase@latest start ...)');
    }
  } finally {
    cliente.close();
  }
}

/// Textos de la pantalla de login (lib/features/auth/presentation/screens/).
bool esLogin(List<NodoUi> nodos) => nodos.any((n) =>
    n.etiqueta.contains('Inicia sesión para continuar') ||
    n.etiqueta.contains('Ingresar'));

/// Espera a que la app termine de abrir: login o una pantalla de adentro.
Future<List<NodoUi>> esperarPantalla(Emulador e,
    {Duration limite = const Duration(seconds: 40)}) async {
  final fin = DateTime.now().add(limite);
  while (DateTime.now().isBefore(fin)) {
    final nodos = await e.ui();
    // La app ya dibuja algo suyo (no la pantalla de inicio de Android)
    if (await e.appAlFrente() && nodos.any((n) => n.etiqueta.trim().isNotEmpty)) {
      return nodos;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  throw const ErrorDeHerramienta('La app no mostró nada en 40 s');
}

/// Si la app está en el login, entra con [c]. Devuelve true si tuvo que
/// iniciar sesión.
Future<bool> iniciarSesionSiHaceFalta(Emulador e, Credenciales c) async {
  final nodos = await esperarPantalla(e);
  if (!esLogin(nodos)) return false;
  // Se vuelve a leer la pantalla antes de cada toque: al abrirse el teclado
  // el formulario sube y las coordenadas de antes caen sobre el teclado.
  Future<NodoUi> campo(String label, int orden) async {
    final campos = (await e.ui()).where((n) => n.esCampo).toList();
    return campos.where((n) => n.etiqueta.contains(label)).firstOrNull ??
        (campos.length > orden
            ? campos[orden]
            : throw ErrorDeHerramienta('No encontré el campo $label del login'));
  }

  // Vacía el campo (el monkey puede haber dejado texto) y escribe
  Future<void> completar(NodoUi n, String texto) async {
    await e.tocar(n);
    await e.tecla('KEYCODE_MOVE_END');
    // El de contraseña no publica su texto (obscureText): se borra de más
    final borrar = n.texto.isEmpty ? 40 : n.texto.length + 2;
    await e.shell('input keyevent ${List.filled(borrar, 67).join(' ')}');
    await e.escribir(texto);
    await Future<void>.delayed(const Duration(seconds: 1));
  }

  await completar(await campo('Email', 0), c.email);
  await completar(await campo('Contraseña', 1), c.password);
  // La contraseña envía con "listo" del teclado (onSubmitted)
  await e.tecla('KEYCODE_ENTER');
  final fin = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(fin)) {
    await Future<void>.delayed(const Duration(seconds: 1));
    final ahora = await e.ui();
    final error = ahora
        .where((n) =>
            n.etiqueta.contains('incorrectos') ||
            n.etiqueta.contains('Sin conexión') ||
            n.etiqueta.contains('Demasiados intentos'))
        .firstOrNull;
    if (error != null) {
      throw ErrorDeHerramienta('El login falló: ${error.etiqueta.trim()}');
    }
    if (!esLogin(ahora)) return true;
  }
  throw const ErrorDeHerramienta('El login no terminó en 30 s');
}

/// Líneas de logcat que indican que la app se cayó: excepción Java sin
/// atrapar, señal nativa (motor de Flutter) o ANR.
List<String> caidasEnLogcat(String log) {
  final lineas = log.split('\n');
  final caidas = <String>[];
  for (var i = 0; i < lineas.length; i++) {
    final l = lineas[i];
    if (l.contains('FATAL EXCEPTION')) {
      final contexto = lineas.skip(i).take(3).join(' ');
      if (contexto.contains(appId)) caidas.add(l.trim());
    } else if (l.contains('ANR in $appId') ||
        (l.contains('Fatal signal') && l.contains(appId)) ||
        l.contains('>>> $appId <<<')) {
      caidas.add(l.trim());
    }
  }
  return caidas;
}

/// Errores de Dart que no tiran la app pero son bugs (excepción no
/// manejada en un Future, error de un widget al dibujar).
List<String> erroresDartEnLogcat(String log) => log
    .split('\n')
    .where((l) =>
        l.contains('Unhandled Exception') ||
        l.contains('EXCEPTION CAUGHT BY') ||
        l.contains('Another exception was thrown'))
    .map((l) => l.trim())
    .toList();
