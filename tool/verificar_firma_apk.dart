// Verifica que un APK esté firmado con la clave oficial de Huantex.
//
//   dart run tool/verificar_firma_apk.dart [ruta.apk]
//
// Sin ruta, verifica build/app/outputs/flutter-apk/app-release.apk. Corre
// `apksigner verify --print-certs` (de <sdk>/build-tools/<versión más nueva>/)
// y compara el SHA-256 del certificado con el oficial (sha256Oficial en
// tool/android_util.dart).
//
// Sale con 0 si coincide, 1 si el APK quedó firmado con otra clave (p. ej. la
// de debug de la PC porque faltaba android/key.properties: ese APK no se
// puede instalar encima de la app oficial) y 2 si no se pudo verificar (no
// existe el APK, falta apksigner, la firma no es válida).
import 'android_util.dart';

Future<void> main(List<String> args) => correrScript(() async {
      if (args.contains('-h') || args.contains('--help')) {
        info('Uso: dart run tool/verificar_firma_apk.dart [ruta.apk]');
        return 0;
      }
      final apk = args.isNotEmpty
          ? args.first
          : unir(raiz, 'build/app/outputs/flutter-apk/app-release.apk');

      paso('Firma de $apk');
      final lista = await firmantes(apk);
      if (lista.isEmpty) {
        throw const ErrorDeHerramienta(
            'apksigner no informó ningún certificado');
      }
      for (final f in lista) {
        info('Firmante: ${f.descripcion}');
      }

      final ajenos = lista.where((f) => !f.esOficial).toList();
      if (ajenos.isEmpty) {
        info('OK: firmado con la clave oficial (SHA-256 $sha256Oficial)');
        return 0;
      }
      info('FALLA: no está firmado con la clave oficial '
          '(se esperaba SHA-256 $sha256Oficial).');
      if (ajenos.any((f) => f.esDebug)) {
        info('Es la clave de debug de esta PC: falta android/key.properties '
            '(y el .jks) al compilar, o es un build profile (Flutter le pone '
            'la firma de debug). Este APK no se instala encima de la app '
            'oficial (INSTALL_FAILED_UPDATE_INCOMPATIBLE).');
      }
      return 1;
    });
