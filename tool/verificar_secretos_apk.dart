// Verifica que un APK no lleve claves secretas adentro. Complementa a
// tool/verificar_firma_apk.dart: aquel mira con qué clave se firmó, este que
// no viaje ninguna clave en el paquete.
//
//   dart run tool/verificar_secretos_apk.dart [ruta.apk] [--key-properties ruta]
//
// Sin ruta, revisa build/app/outputs/flutter-apk/app-release.apk. Recorre
// todas las entradas del zip y busca en:
// - classes*.dex (Kotlin/Java de la app y de los plugins);
// - lib/<abi>/libapp.so: el snapshot AOT de Dart (release/profile), donde
//   quedan los strings de la app y los valores de --dart-define;
// - assets/ (en un build debug el código Dart va en
//   assets/flutter_assets/kernel_blob.bin, con los mismos strings);
// - res/, resources.arsc y AndroidManifest.xml (meta-data, strings).
// Las demás .so (libflutter.so, plugins nativos) son binarios de terceros y
// META-INF/ es la firma: no se revisan.
//
// Qué busca:
// - un JWT cuyo payload diga "role":"service_role" (la service key de
//   Supabase): saltea RLS, da acceso total a la base;
// - claves sb_secret_ (la secret key nueva de Supabase, lo mismo);
// - -----BEGIN ... PRIVATE KEY----- seguido del cuerpo en base64 (el
//   encabezado solo no es una clave: dart_jsonwebtoken, que trae gotrue,
//   tiene las constantes de su parser PEM y el kernel de un build debug las
//   lleva);
// - cadenas de conexión postgres:// o postgresql://;
// - el keystore de la firma (android/app/build.gradle.kts lee
//   android/key.properties): storePassword=/keyPassword= copiados al APK, un
//   .jks/.keystore/.p12 (por nombre o por los bytes FEEDFEED de JKS) y, si
//   existe android/key.properties (o --key-properties), sus contraseñas
//   literales en cualquier entrada revisada.
// La publishable key (sb_publishable_...) y la anon key (un JWT con
// "role":"anon") son públicas a propósito: van en la app y no se marcan.
//
// Cada entrada se mira byte a byte (UTF-8, el MUTF-8 de los .dex y los
// strings de un byte de Dart) y como UTF-16LE en las dos alineaciones (los
// string pools de resources.arsc y del XML binario, los strings de Dart con
// caracteres fuera de Latin-1).
//
// Sale con 0 si no encontró nada, 1 si encontró algo y 2 si no pudo revisar
// (no existe el APK, no es un zip que entienda). Nunca imprime el secreto:
// solo el tipo, la entrada del zip y los primeros 6 caracteres (de una
// contraseña del keystore ni eso).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'android_util.dart';

Future<void> main(List<String> args) => correrScript(() async {
      if (args.contains('-h') || args.contains('--help')) {
        info('Uso: dart run tool/verificar_secretos_apk.dart [ruta.apk] '
            '[--key-properties ruta]');
        return 0;
      }
      String? apk;
      String? keyProperties;
      for (var i = 0; i < args.length; i++) {
        if (args[i] == '--key-properties') {
          if (i + 1 >= args.length) {
            throw const ErrorDeHerramienta('Falta la ruta de --key-properties');
          }
          keyProperties = args[++i];
        } else {
          apk ??= args[i];
        }
      }
      apk ??= unir(raiz, 'build/app/outputs/flutter-apk/app-release.apk');

      final archivo = File(apk);
      if (!archivo.existsSync()) {
        throw ErrorDeHerramienta('No existe $apk');
      }
      final props = File(
          keyProperties ?? unir(raiz, unir('android', 'key.properties')));
      final contrasenas = props.existsSync()
          ? contrasenasDeKeyProperties(props.readAsStringSync())
          : const <String, String>{};
      if (keyProperties != null && !props.existsSync()) {
        throw ErrorDeHerramienta('No existe $keyProperties');
      }

      paso('Secretos en $apk');
      final revision = revisarApk(archivo.readAsBytesSync(),
          contrasenas: contrasenas);
      info('Revisadas ${revision.revisadas.length} de ${revision.entradas} '
          'entradas (${(revision.bytes / 1048576).toStringAsFixed(1)} MB sin '
          'comprimir)${contrasenas.isEmpty ? '' : ', con las contraseñas de '
              '${props.path}'}.');
      if (revision.hallazgos.isEmpty) {
        info('OK: sin JWT service_role, sb_secret_, claves privadas, '
            'postgres:// ni datos del keystore.');
        return 0;
      }
      for (final h in revision.hallazgos) {
        info('FALLA: $h');
      }
      info('${revision.hallazgos.length} secreto(s) en el APK. Una clave que '
          'viajó en un APK publicado hay que rotarla: no alcanza con sacarla '
          'del próximo build.');
      return 1;
    });

enum TipoDeSecreto {
  jwtServiceRole('JWT con role service_role'),
  secretKey('clave sb_secret_'),
  clavePrivada('clave privada PEM'),
  postgres('cadena de conexión postgres'),
  contrasenaKeystore('contraseña del keystore'),
  keystore('keystore');

  const TipoDeSecreto(this.descripcion);
  final String descripcion;
}

/// Un secreto encontrado, sin el secreto: [muestra] son sus primeros 6
/// caracteres (o de qué se trata, si mostrar el principio revela demasiado).
class Hallazgo {
  const Hallazgo(this.tipo, this.entrada, this.muestra);

  final TipoDeSecreto tipo;
  final String entrada;
  final String muestra;

  @override
  String toString() => '${tipo.descripcion} en $entrada: $muestra';

  @override
  bool operator ==(Object other) =>
      other is Hallazgo &&
      other.tipo == tipo &&
      other.entrada == entrada &&
      other.muestra == muestra;

  @override
  int get hashCode => Object.hash(tipo, entrada, muestra);
}

class Revision {
  Revision(this.entradas, this.revisadas, this.bytes, this.hallazgos);

  /// Cantidad de entradas del zip.
  final int entradas;

  /// Las que se revisaron (ver [debeRevisarse]).
  final List<String> revisadas;

  /// Bytes sin comprimir revisados.
  final int bytes;
  final List<Hallazgo> hallazgos;
}

/// Las entradas donde puede quedar un string de la app.
bool debeRevisarse(String nombre) =>
    RegExp(r'^classes\d*\.dex$').hasMatch(nombre) ||
    RegExp(r'^lib/[^/]+/libapp\.so$').hasMatch(nombre) ||
    nombre.startsWith('assets/') ||
    nombre.startsWith('res/') ||
    nombre == 'resources.arsc' ||
    nombre == 'AndroidManifest.xml';

/// `storePassword` y `keyPassword` de un key.properties (formato
/// java.util.Properties simple: `clave=valor`, `#` y `!` son comentarios).
Map<String, String> contrasenasDeKeyProperties(String texto) {
  final contrasenas = <String, String>{};
  for (final linea in const LineSplitter().convert(texto)) {
    final l = linea.trim();
    if (l.isEmpty || l.startsWith('#') || l.startsWith('!')) continue;
    final m = RegExp(r'^(storePassword|keyPassword)\s*[=:]\s*(.*)$')
        .firstMatch(l);
    if (m != null && m[2]!.isNotEmpty) contrasenas[m[1]!] = m[2]!;
  }
  return contrasenas;
}

/// Revisa un APK (un zip) completo. [contrasenas] son las del keystore
/// (`storePassword` → valor) para buscarlas literales.
Revision revisarApk(Uint8List apk,
    {Map<String, String> contrasenas = const {}}) {
  final entradas = leerZip(apk);
  final revisadas = <String>[];
  final hallazgos = <Hallazgo>{};
  var bytes = 0;
  for (final e in entradas) {
    if (_esKeystorePorNombre(e.nombre)) {
      hallazgos.add(Hallazgo(TipoDeSecreto.keystore, e.nombre,
          'archivo ${e.nombre.split('/').last}'));
    }
    if (!debeRevisarse(e.nombre) || e.nombre.endsWith('/')) continue;
    final datos = e.contenido(apk);
    revisadas.add(e.nombre);
    bytes += datos.length;
    hallazgos.addAll(buscarEnContenido(e.nombre, datos,
        contrasenas: contrasenas));
  }
  return Revision(entradas.length, revisadas, bytes, hallazgos.toList());
}

bool _esKeystorePorNombre(String nombre) {
  final n = nombre.toLowerCase();
  return n.endsWith('.jks') ||
      n.endsWith('.keystore') ||
      n.endsWith('.p12') ||
      n.endsWith('.pfx') ||
      n.split('/').last == 'key.properties';
}

final _jwt = RegExp(
    r'eyJ[A-Za-z0-9_-]{8,}\.([A-Za-z0-9_-]{8,})\.[A-Za-z0-9_-]{8,}');
final _rolServicio = RegExp(r'"role"\s*:\s*"service_role"');
final _encabezadoPem = RegExp(r'-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----');

/// Una línea de base64 de una clave (las de un PEM tienen 64 caracteres).
final _cuerpoPem = RegExp(r'[A-Za-z0-9+/]{40,}');

final _patrones = <TipoDeSecreto, RegExp>{
  TipoDeSecreto.secretKey: RegExp(r'sb_secret_[A-Za-z0-9_-]{16,}'),
  TipoDeSecreto.postgres:
      RegExp(r'''postgres(?:ql)?://[^\s"'<>\\\x00-\x1f\x7f-\xff]{3,}'''),
  TipoDeSecreto.contrasenaKeystore:
      RegExp(r'(?:storePassword|keyPassword)\s*[=:]\s*[^\s\x00-\x1f]{1,}'),
};

/// Los secretos de una entrada ([nombre] es su ruta en el zip).
List<Hallazgo> buscarEnContenido(String nombre, Uint8List datos,
    {Map<String, String> contrasenas = const {}}) {
  final hallazgos = <Hallazgo>{};
  void agregar(TipoDeSecreto tipo, String texto) =>
      hallazgos.add(Hallazgo(tipo, nombre, '${_principio(texto)}…'));

  if (datos.length >= 4 &&
      datos[0] == 0xFE &&
      datos[1] == 0xED &&
      datos[2] == 0xFE &&
      datos[3] == 0xED) {
    hallazgos.add(
        Hallazgo(TipoDeSecreto.keystore, nombre, 'bytes de un keystore JKS'));
  }
  for (final texto in _vistas(datos)) {
    for (final m in _jwt.allMatches(texto)) {
      if (_esServiceRole(m[1]!)) agregar(TipoDeSecreto.jwtServiceRole, m[0]!);
    }
    for (final m in _encabezadoPem.allMatches(texto)) {
      if (_tieneCuerpoPem(texto, m.end)) {
        agregar(TipoDeSecreto.clavePrivada, m[0]!);
      }
    }
    for (final MapEntry(key: tipo, value: patron) in _patrones.entries) {
      for (final m in patron.allMatches(texto)) {
        agregar(tipo, m[0]!);
      }
    }
    for (final MapEntry(key: clave, value: valor) in contrasenas.entries) {
      // Una contraseña corta aparece por casualidad en cualquier binario
      if (valor.length >= 6 && texto.contains(valor)) {
        hallazgos.add(Hallazgo(TipoDeSecreto.contrasenaKeystore, nombre,
            '$clave de key.properties (${valor.length} caracteres)'));
      }
    }
  }
  return hallazgos.toList();
}

String _principio(String texto) =>
    texto.length <= 6 ? texto : texto.substring(0, 6);

/// Después del encabezado PEM que termina en [desde] viene una clave: una
/// línea de base64 antes del `-----END` (con saltos de línea reales o
/// escritos `\n`, y los encabezados `Proc-Type:` de una clave cifrada).
bool _tieneCuerpoPem(String texto, int desde) {
  var cuerpo = texto.substring(desde, (desde + 400).clamp(0, texto.length));
  final fin = cuerpo.indexOf('-----');
  if (fin >= 0) cuerpo = cuerpo.substring(0, fin);
  return _cuerpoPem.hasMatch(cuerpo);
}

/// El payload (base64url) de un JWT dice `"role":"service_role"`.
bool _esServiceRole(String payload) {
  try {
    final json = utf8.decode(base64Url.decode(base64Url.normalize(payload)),
        allowMalformed: true);
    return _rolServicio.hasMatch(json);
  } on FormatException {
    return false;
  }
}

/// Los bytes como texto: uno por carácter (UTF-8 y Latin-1 quedan con sus
/// letras ASCII seguidas) y como UTF-16LE desde el byte 0 y desde el 1.
Iterable<String> _vistas(Uint8List datos) sync* {
  yield latin1.decode(datos);
  final bd = ByteData.sublistView(datos);
  for (final desde in const [0, 1]) {
    final n = (datos.length - desde) ~/ 2;
    if (n <= 0) continue;
    final unidades = Uint16List(n);
    for (var i = 0; i < n; i++) {
      unidades[i] = bd.getUint16(desde + 2 * i, Endian.little);
    }
    yield String.fromCharCodes(unidades);
  }
}

// ===== Zip =====
//
// Lector mínimo (solo dart:io, como el resto de tool/): el directorio
// central, y cada entrada guardada (0) o con deflate (8). Sin zip64: un APK
// no llega a 4 GB.

class EntradaZip {
  EntradaZip(this.nombre, this.metodo, this.comprimido, this.tamano,
      this.desplazamiento);

  final String nombre;
  final int metodo;
  final int comprimido;
  final int tamano;

  /// Dónde empieza su cabecera local.
  final int desplazamiento;

  Uint8List contenido(Uint8List zip) {
    final bd = ByteData.sublistView(zip);
    if (desplazamiento + 30 > zip.length ||
        bd.getUint32(desplazamiento, Endian.little) != 0x04034b50) {
      throw ErrorDeHerramienta('$nombre: cabecera local inválida');
    }
    final inicio = desplazamiento +
        30 +
        bd.getUint16(desplazamiento + 26, Endian.little) +
        bd.getUint16(desplazamiento + 28, Endian.little);
    if (inicio + comprimido > zip.length) {
      throw ErrorDeHerramienta('$nombre: el zip está cortado');
    }
    final datos = Uint8List.sublistView(zip, inicio, inicio + comprimido);
    switch (metodo) {
      case 0:
        return datos;
      case 8:
        return Uint8List.fromList(ZLibDecoder(raw: true).convert(datos));
      default:
        throw ErrorDeHerramienta(
            '$nombre: método de compresión $metodo no soportado');
    }
  }
}

/// Las entradas del directorio central de un zip.
List<EntradaZip> leerZip(Uint8List zip) {
  final bd = ByteData.sublistView(zip);
  // Fin del directorio central: 22 bytes + un comentario de hasta 64 KB
  var fin = -1;
  for (var i = zip.length - 22; i >= 0 && i >= zip.length - 22 - 0xFFFF; i--) {
    if (bd.getUint32(i, Endian.little) == 0x06054b50) {
      fin = i;
      break;
    }
  }
  if (fin < 0) {
    throw const ErrorDeHerramienta(
        'No es un zip (no tiene directorio central): ¿es un APK?');
  }
  final cantidad = bd.getUint16(fin + 10, Endian.little);
  final inicio = bd.getUint32(fin + 16, Endian.little);
  if (cantidad == 0xFFFF || inicio == 0xFFFFFFFF) {
    throw const ErrorDeHerramienta('Zip64 no soportado');
  }
  final entradas = <EntradaZip>[];
  var p = inicio;
  for (var i = 0; i < cantidad; i++) {
    if (p + 46 > zip.length || bd.getUint32(p, Endian.little) != 0x02014b50) {
      throw const ErrorDeHerramienta('Directorio central del zip inválido');
    }
    final largoNombre = bd.getUint16(p + 28, Endian.little);
    final largoExtra = bd.getUint16(p + 30, Endian.little);
    final largoComentario = bd.getUint16(p + 32, Endian.little);
    entradas.add(EntradaZip(
      utf8.decode(zip.sublist(p + 46, p + 46 + largoNombre),
          allowMalformed: true),
      bd.getUint16(p + 10, Endian.little),
      bd.getUint32(p + 20, Endian.little),
      bd.getUint32(p + 24, Endian.little),
      bd.getUint32(p + 42, Endian.little),
    ));
    p += 46 + largoNombre + largoExtra + largoComentario;
  }
  return entradas;
}
