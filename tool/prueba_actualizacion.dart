// Prueba de actualización en el EMULADOR: instala la versión anterior
// (compilada desde --base, por defecto origin/main, en un worktree temporal),
// inicia sesión con el usuario de prueba y encima instala la nueva (este
// worktree, con sus cambios sin commitear) con `adb install -r`, como cuando
// el celular recibe un APK nuevo. Verifica que:
//   1. las dos quedaron firmadas con la misma clave (si no, Android rechaza
//      la actualización con INSTALL_FAILED_UPDATE_INCOMPATIBLE);
//   2. `adb install -r` actualiza (no reinstala: firstInstallTime no cambia);
//   3. la nueva abre sin caerse (topResumedActivity, sin FATAL EXCEPTION/ANR
//      en logcat);
//   4. los datos de la app sobreviven: la sesión guardada sigue (abre adentro,
//      no en el login).
//
//   dart run tool/prueba_actualizacion.dart [--base origin/main]
//       [--serial emulator-5554] [--env env/local-android.json]
//       [--env-pc env/local.json] [--sin-compilar | --solo-compilar]
//
// Las dos se compilan en --profile con --dart-define-from-file=env/local-android.json:
// profile permite http (android/app/src/profile/AndroidManifest.xml) para
// llegar al Supabase local desde el emulador (10.0.2.2). Ojo: Flutter crea el
// build type profile copiando el de debug ANTES de que build.gradle.kts le
// asigne la firma, así que profile sale con la clave de debug de esta PC (no
// la oficial): sirve para probar la actualización entre dos builds de esta
// PC. La firma oficial del release se verifica con tool/verificar_firma_apk.dart.
//
// Necesita el emulador prendido y el Supabase local levantado. Solo corre en
// emuladores (desinstala la app). Deja los APK y el logcat en
// build/actualizacion/. --sin-compilar reusa los APK que ya estén ahí.
// Con poca RAM (Gradle + emulador no entran juntos): primero
// --solo-compilar con el emulador apagado, después --sin-compilar.
import 'dart:io';

import 'android_util.dart';

String _opcion(List<String> args, String nombre, String porDefecto) {
  final i = args.indexOf(nombre);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : porDefecto;
}

Future<void> main(List<String> args) => correrScript(() async {
      final base = _opcion(args, '--base', 'origin/main');
      final serial = _opcion(args, '--serial', serialPorDefecto);
      final env = File(_opcion(args, '--env', 'env/local-android.json'))
          .absolute
          .path;
      final envPc = _opcion(args, '--env-pc', 'env/local.json');
      final sinCompilar = args.contains('--sin-compilar');

      final salida = Directory(unir(raiz, unir('build', 'actualizacion')))
        ..createSync(recursive: true);
      final anterior = unir(salida.path, 'anterior.apk');
      final nueva = unir(salida.path, 'nueva.apk');

      final soloCompilar = args.contains('--solo-compilar');
      final emulador = Emulador(serial);
      final credenciales = Credenciales.deIntegracion();
      if (!soloCompilar) {
        await emulador.verificarConectado();
        await emulador.despertar();
        await asegurarUsuario(credenciales, envPc);
      }

      // ===== Compilar =====
      if (!sinCompilar || !File(nueva).existsSync()) {
        paso('Compilando la versión NUEVA (este worktree) en profile');
        await _compilarProfile(raiz, env, nueva);
      }
      final commitBase =
          '${(await correr('git', ['rev-parse', '--short', base], dir: raiz)).stdout}'
              .trim();
      if (commitBase.isEmpty) {
        throw ErrorDeHerramienta('No existe la referencia $base');
      }
      if (!sinCompilar || !File(anterior).existsSync()) {
        paso('Compilando la versión ANTERIOR ($base = $commitBase) en profile');
        await _compilarBase(base, env, anterior);
      }
      if (soloCompilar) {
        info('APKs listos en ${salida.path}: seguir con --sin-compilar');
        return 0;
      }

      // ===== Firmas =====
      paso('Firmas');
      final firmaAnterior = await firmantes(anterior);
      final firmaNueva = await firmantes(nueva);
      info('Anterior: ${firmaAnterior.map((f) => f.descripcion).join(', ')}');
      info('Nueva:    ${firmaNueva.map((f) => f.descripcion).join(', ')}');
      final mismas = firmaAnterior.map((f) => f.sha256).toSet().containsAll(
              firmaNueva.map((f) => f.sha256)) &&
          firmaAnterior.length == firmaNueva.length;
      if (!mismas) {
        info('FALLA: firmas distintas, Android no va a aceptar la actualización');
        return 1;
      }
      info('OK: misma clave en las dos');

      final fallas = <String>[];

      // ===== Instalar la anterior y entrar =====
      paso('Instalando la ANTERIOR desde cero e iniciando sesión');
      await emulador.desinstalar();
      await emulador.instalar(anterior, reemplazar: false);
      final instaladaEn = await _fechaInstalacion(emulador);
      await emulador.limpiarLogcat();
      await emulador.abrirApp();
      final entro = await iniciarSesionSiHaceFalta(emulador, credenciales);
      info(entro ? 'Sesión iniciada' : 'Ya había sesión');
      await Future<void>.delayed(const Duration(seconds: 3));
      final caidasAnterior = caidasEnLogcat(await emulador.logcat());
      if (caidasAnterior.isNotEmpty) {
        fallas.add('La anterior se cayó: ${caidasAnterior.first}');
      }

      // ===== Actualizar =====
      paso('Actualizando con la NUEVA (adb install -r)');
      await emulador.limpiarLogcat();
      info(await emulador.instalar(nueva, reemplazar: true));
      final actualizadaEn = await _fechaInstalacion(emulador);
      if (instaladaEn.primera != actualizadaEn.primera) {
        fallas.add('firstInstallTime cambió: se reinstaló en vez de actualizar');
      } else if (instaladaEn.ultima == actualizadaEn.ultima) {
        fallas.add('lastUpdateTime no cambió: la actualización no se aplicó');
      } else {
        info('OK: actualizada (firstInstallTime ${actualizadaEn.primera}, '
            'lastUpdateTime ${actualizadaEn.ultima})');
      }

      // ===== Abrir la nueva =====
      paso('Abriendo la NUEVA');
      await emulador.abrirApp();
      final nodos = await esperarPantalla(emulador);
      await Future<void>.delayed(const Duration(seconds: 5));
      final log = await emulador.logcat();
      File(unir(salida.path, 'logcat.txt')).writeAsStringSync(log);
      final caidas = caidasEnLogcat(log);
      if (caidas.isNotEmpty) fallas.add('La nueva se cayó: ${caidas.first}');
      if (!await emulador.appAlFrente()) {
        fallas.add('La nueva no quedó al frente (topResumedActivity)');
      }
      if (!await emulador.appViva()) fallas.add('El proceso de la app murió');
      if (esLogin(nodos)) {
        fallas.add('Se perdió la sesión: la nueva abrió en el login');
      } else {
        info('OK: la sesión guardada sobrevivió (abrió adentro, sin login)');
      }
      final errores = erroresDartEnLogcat(log);
      if (errores.isNotEmpty) {
        info('Aviso: ${errores.length} errores de Dart en logcat '
            '(no tiran la app), p. ej.: ${errores.first}');
      }

      paso('Resultado');
      if (fallas.isEmpty) {
        info('OK: $base ($commitBase) → este worktree se actualiza sin '
            'perder datos ni caerse. Logcat en ${salida.path}');
        return 0;
      }
      for (final f in fallas) {
        info('FALLA: $f');
      }
      return 1;
    });

/// `flutter build apk --profile` en [dir] y copia el APK a [destino].
Future<void> _compilarProfile(String dir, String env, String destino) async {
  final codigo = await correrVisible(flutter,
      ['build', 'apk', '--profile', '--dart-define-from-file=$env'],
      dir: dir);
  if (codigo != 0) {
    throw ErrorDeHerramienta('flutter build apk --profile falló en $dir');
  }
  File(unir(dir, 'build/app/outputs/flutter-apk/app-profile.apk'))
      .copySync(destino);
  info('APK: $destino');
}

/// Compila [base] en un worktree temporal (fuera del repo, para que el
/// analizador y flutter no lo vean) y lo borra al terminar.
Future<void> _compilarBase(String base, String env, String destino) async {
  final temporal = Directory.systemTemp.createTempSync('ventas_app_anterior_');
  final r = await correr(
      'git', ['worktree', 'add', '--detach', temporal.path, base],
      dir: raiz);
  if (r.exitCode != 0) {
    throw ErrorDeHerramienta('git worktree add falló:\n${r.stderr}');
  }
  try {
    await _compilarProfile(temporal.path, env, destino);
  } finally {
    await correr('git', ['worktree', 'remove', '--force', temporal.path],
        dir: raiz);
    if (temporal.existsSync()) temporal.deleteSync(recursive: true);
  }
}

typedef _Fechas = ({String primera, String ultima});

Future<_Fechas> _fechaInstalacion(Emulador e) async {
  final s = await e.shell('dumpsys package $appId');
  String leer(String clave) =>
      RegExp('$clave=([^\\n\\r]+)').firstMatch(s)?.group(1)?.trim() ?? '';
  return (primera: leer('firstInstallTime'), ultima: leer('lastUpdateTime'));
}
