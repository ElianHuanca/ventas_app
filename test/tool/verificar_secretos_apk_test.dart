// Tests de tool/verificar_secretos_apk.dart con APKs de mentira armados en
// memoria. El zip lo escribe `archive` (otra implementación que el lector
// del escáner), con entradas comprimidas (deflate) y guardadas, como un APK
// real (resources.arsc y las .so van sin comprimir).
//
// Los secretos de prueba se arman al correr (con join): el repo es público y
// un literal con forma de clave lo marcaría el secret scanning de GitHub.
import 'dart:convert';
import 'dart:typed_data';

// archive llega con pdf (es el que arma el PDF de faltantes); no se agrega al
// pubspec solo para este test.
// ignore: depend_on_referenced_packages
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/android_util.dart' show ErrorDeHerramienta;
import '../../tool/verificar_secretos_apk.dart';

/// Un APK (zip) con [entradas] (`String` en UTF-8 o bytes). Las de
/// [sinComprimir] van guardadas (método 0); el resto con deflate.
Uint8List armarApk(Map<String, Object> entradas,
    {Set<String> sinComprimir = const {}}) {
  final zip = Archive();
  for (final MapEntry(:key, :value) in entradas.entries) {
    final bytes = value is String ? utf8.encode(value) : value as List<int>;
    zip.addFile(sinComprimir.contains(key)
        ? ArchiveFile.noCompress(key, bytes.length, bytes)
        : ArchiveFile.bytes(key, bytes));
  }
  return ZipEncoder().encodeBytes(zip);
}

/// Bytes con [texto] metido entre basura binaria, como un string en un
/// binario (libapp.so, classes.dex).
Uint8List enBinario(String texto, {bool utf16 = false, int relleno = 37}) {
  final basura = [for (var i = 0; i < relleno; i++) (i * 73 + 11) % 256];
  final medio = utf16
      ? [
          for (final u in texto.codeUnits) ...[u & 0xFF, u >> 8],
        ]
      : latin1.encode(texto);
  return Uint8List.fromList([...basura, 0, ...medio, 0, ...basura]);
}

String _b64(Object json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

String jwt(String rol) => [
      _b64({'alg': 'HS256', 'typ': 'JWT'}),
      _b64({'iss': 'supabase', 'ref': 'tacgylhmwqkfhdkpcvkr', 'role': rol}),
      'c2lnbmF0dXJhX2RlX3BydWViYV9xdWVfbm9fZXNfcmVhbA',
    ].join('.');

final serviceRole = jwt(['service', 'role'].join('_'));
final anon = jwt('anon');
final secretKey = ['sb', 'secret', 'N7UND0UgjKTVK-Uodkm0Hg', 'xSvEMPvz'].join('_');
final publishable =
    ['sb', 'publishable', 'sv1GE4d', '2rZImM37tGMb7w', 'nzQDMwhf'].join('_');
final pem = [
  ['-----BEGIN', 'PRIVATE', 'KEY-----'].join(' '),
  'MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7',
  ['-----END', 'PRIVATE', 'KEY-----'].join(' '),
].join('\n');
final postgres = [
  'postgresql:',
  '',
  'postgres.tacgylhmwqkfhdkpcvkr:clave@aws-1-us-west-2.pooler.supabase.com:5432',
  'postgres',
].join('/');

void main() {
  List<Hallazgo> hallazgos(Uint8List apk,
          {Map<String, String> contrasenas = const {}}) =>
      revisarApk(apk, contrasenas: contrasenas).hallazgos;

  group('APK sin secretos', () {
    test(
        'la publishable key, la anon key y la URL de Supabase son públicas: '
        'no se marcan', () {
      final apk = armarApk({
        'AndroidManifest.xml': enBinario('com.example.textiles_app',
            utf16: true),
        'classes.dex': enBinario('io.flutter.embedding.android.FlutterActivity'),
        'lib/arm64-v8a/libapp.so': enBinario(
            'https://tacgylhmwqkfhdkpcvkr.supabase.co $publishable $anon'),
        'assets/flutter_assets/AssetManifest.bin': 'fonts/MaterialIcons',
        'res/xml/paths.xml': enBinario('external_files', utf16: true),
        'resources.arsc': enBinario('Huantex', utf16: true),
      }, sinComprimir: {
        'lib/arm64-v8a/libapp.so',
        'resources.arsc'
      });

      final revision = revisarApk(apk);

      expect(revision.hallazgos, isEmpty);
      expect(revision.entradas, 6);
      expect(revision.revisadas, hasLength(6));
    });

    test(
        'los encabezados PEM sueltos (las constantes del parser de '
        'dart_jsonwebtoken, en el kernel de un build debug) no son una clave',
        () {
      final inicio = ['-----BEGIN', 'PRIVATE', 'KEY-----'].join(' ');
      final fin = ['-----END', 'PRIVATE', 'KEY-----'].join(' ');
      final apk = armarApk({
        'assets/flutter_assets/kernel_blob.bin': enBinario(
            "static const BEGIN_PRIVATE_KEY = '$inicio';\n"
            "static const END_PRIVATE_KEY = '$fin';\n"
            'EdDSAPublicKeysecp256r1$inicio$fin'),
      });

      expect(hallazgos(apk), isEmpty);
    });

    test('lee entradas guardadas y con deflate (el contenido llega entero)', () {
      final texto = 'Hubo un error ' * 1000;
      final apk = armarApk({'assets/a.txt': texto, 'assets/b.txt': texto},
          sinComprimir: {'assets/b.txt'});

      final entradas = {for (final e in leerZip(apk)) e.nombre: e};

      expect(entradas['assets/a.txt']!.metodo, 8);
      expect(entradas['assets/b.txt']!.metodo, 0);
      for (final e in entradas.values) {
        expect(utf8.decode(e.contenido(apk)), texto);
      }
    });
  });

  group('encuentra', () {
    test('un JWT con role service_role en libapp.so (y no la anon de al lado)',
        () {
      final apk = armarApk({
        'lib/arm64-v8a/libapp.so': enBinario('$anon $serviceRole'),
      }, sinComprimir: {
        'lib/arm64-v8a/libapp.so'
      });

      expect(hallazgos(apk), [
        Hallazgo(TipoDeSecreto.jwtServiceRole, 'lib/arm64-v8a/libapp.so',
            '${serviceRole.substring(0, 6)}…'),
      ]);
    });

    test('una clave sb_secret_ en classes.dex y en classes2.dex', () {
      final apk = armarApk({
        'classes.dex': enBinario(secretKey),
        'classes2.dex': enBinario('const KEY = "$secretKey";'),
      });

      expect(hallazgos(apk).map((h) => (h.tipo, h.entrada, h.muestra)),
          unorderedEquals([
            (TipoDeSecreto.secretKey, 'classes.dex', 'sb_sec…'),
            (TipoDeSecreto.secretKey, 'classes2.dex', 'sb_sec…'),
          ]));
    });

    test('una clave privada PEM en assets/, suelta y dentro de un JSON', () {
      final apk = armarApk({
        'assets/flutter_assets/assets/cert.pem': pem,
        // En JSON los saltos de línea quedan escritos como \n
        'assets/flutter_assets/assets/cuenta.json':
            jsonEncode({'private_key': pem}),
      });

      expect(hallazgos(apk).map((h) => (h.tipo, h.entrada, h.muestra)),
          unorderedEquals([
            (
              TipoDeSecreto.clavePrivada,
              'assets/flutter_assets/assets/cert.pem',
              '-----B…'
            ),
            (
              TipoDeSecreto.clavePrivada,
              'assets/flutter_assets/assets/cuenta.json',
              '-----B…'
            ),
          ]));
    });

    test(
        'una cadena postgres en res/ (UTF-16) y en resources.arsc (UTF-16 '
        'desde un byte impar)', () {
      final postgresSinQl = postgres.replaceFirst('postgresql:', 'postgres:');
      final arsc = enBinario(postgres, utf16: true, relleno: 41);
      final apk = armarApk({
        'res/values/strings.xml': enBinario(postgresSinQl, utf16: true),
        'resources.arsc': arsc,
      }, sinComprimir: {
        'resources.arsc'
      });

      expect(hallazgos(apk).map((h) => (h.tipo, h.entrada, h.muestra)),
          unorderedEquals([
            (TipoDeSecreto.postgres, 'res/values/strings.xml', 'postgr…'),
            (TipoDeSecreto.postgres, 'resources.arsc', 'postgr…'),
          ]));
    });

    test(
        'las contraseñas del keystore: key.properties copiado y la contraseña '
        'literal en libapp.so', () {
      final apk = armarApk({
        'assets/flutter_assets/assets/firma.txt':
            'storePassword=Cl4veDeLaTienda\nkeyAlias=huantex',
        'lib/arm64-v8a/libapp.so': enBinario('xxCl4veDeLaTiendaxx'),
      });

      final encontrados = hallazgos(apk,
          contrasenas: {'storePassword': 'Cl4veDeLaTienda'});

      expect(encontrados.map((h) => (h.tipo, h.entrada, h.muestra)),
          unorderedEquals([
            (
              TipoDeSecreto.contrasenaKeystore,
              'assets/flutter_assets/assets/firma.txt',
              'storeP…'
            ),
            (
              TipoDeSecreto.contrasenaKeystore,
              'assets/flutter_assets/assets/firma.txt',
              'storePassword de key.properties (15 caracteres)'
            ),
            (
              TipoDeSecreto.contrasenaKeystore,
              'lib/arm64-v8a/libapp.so',
              'storePassword de key.properties (15 caracteres)'
            ),
          ]));
    });

    test('un keystore: por el nombre (en cualquier carpeta) y por sus bytes',
        () {
      final jks = Uint8List.fromList([0xFE, 0xED, 0xFE, 0xED, 0, 0, 0, 2]);
      final apk = armarApk({
        'assets/flutter_assets/assets/huantex-release.jks': jks,
        'assets/flutter_assets/assets/datos.bin': jks,
        'META-INF/key.properties': 'keyAlias=huantex',
      });

      expect(hallazgos(apk).map((h) => (h.tipo, h.entrada)),
          unorderedEquals([
            (
              TipoDeSecreto.keystore,
              'assets/flutter_assets/assets/huantex-release.jks'
            ),
            (
              TipoDeSecreto.keystore,
              'assets/flutter_assets/assets/huantex-release.jks'
            ),
            (TipoDeSecreto.keystore, 'assets/flutter_assets/assets/datos.bin'),
            (TipoDeSecreto.keystore, 'META-INF/key.properties'),
          ]));
    });

    test('el mismo secreto repetido en una entrada se informa una vez', () {
      final apk = armarApk({
        'lib/x86_64/libapp.so': enBinario('$secretKey $secretKey $secretKey'),
      });

      expect(hallazgos(apk), hasLength(1));
    });
  });

  test('nunca muestra el secreto completo, solo el tipo, la entrada y 6 '
      'caracteres', () {
    final apk = armarApk({
      'lib/arm64-v8a/libapp.so':
          enBinario('$serviceRole $secretKey $postgres $pem'),
    });

    final encontrados = hallazgos(apk);

    expect(encontrados, hasLength(4));
    for (final h in encontrados) {
      final texto = '$h';
      expect(texto, contains('lib/arm64-v8a/libapp.so'));
      expect(texto, contains(h.tipo.descripcion));
      expect(h.muestra.replaceAll('…', ''), hasLength(6));
      for (final secreto in [serviceRole, secretKey, postgres, pem]) {
        expect(texto, isNot(contains(secreto.substring(0, 12))));
      }
    }
  });

  test('no revisa libflutter.so, otras .so ni META-INF (binarios de terceros y '
      'la firma)', () {
    final apk = armarApk({
      'lib/arm64-v8a/libflutter.so': enBinario(secretKey),
      'lib/arm64-v8a/libimage_picker.so': enBinario(secretKey),
      'META-INF/CERT.RSA': enBinario(pem),
      'kotlin/collections/collections.kotlin_builtins': enBinario(postgres),
    });

    final revision = revisarApk(apk);

    expect(revision.hallazgos, isEmpty);
    expect(revision.revisadas, isEmpty);
    expect(debeRevisarse('lib/arm64-v8a/libapp.so'), isTrue);
    expect(debeRevisarse('lib/armeabi-v7a/libapp.so'), isTrue);
    expect(debeRevisarse('classes3.dex'), isTrue);
    expect(debeRevisarse('assets/flutter_assets/kernel_blob.bin'), isTrue);
    expect(debeRevisarse('res/raw/datos.json'), isTrue);
    expect(debeRevisarse('resources.arsc'), isTrue);
    expect(debeRevisarse('lib/arm64-v8a/libflutter.so'), isFalse);
    expect(debeRevisarse('META-INF/MANIFEST.MF'), isFalse);
    expect(debeRevisarse('dex/classes.dex'), isFalse);
  });

  test('contrasenasDeKeyProperties lee storePassword y keyPassword', () {
    const texto = '# Firma de Huantex\r\n'
        'storePassword=uno-dos-tres\r\n'
        'keyPassword = cuatro:cinco\r\n'
        '! comentario\r\n'
        'keyAlias=huantex\r\n'
        'storeFile=F:\\\\Elian\\\\claves\\\\huantex-release.jks\r\n';

    expect(contrasenasDeKeyProperties(texto),
        {'storePassword': 'uno-dos-tres', 'keyPassword': 'cuatro:cinco'});
  });

  test('una contraseña de menos de 6 caracteres no se busca (aparece por '
      'casualidad en cualquier binario)', () {
    final apk = armarApk({'classes.dex': enBinario('abc')});

    expect(hallazgos(apk, contrasenas: {'keyPassword': 'abc'}), isEmpty);
  });

  test('un archivo que no es zip es un error de la herramienta (sale con 2)',
      () {
    expect(() => revisarApk(Uint8List.fromList(utf8.encode('no soy un apk'))),
        throwsA(isA<ErrorDeHerramienta>()));
  });
}
