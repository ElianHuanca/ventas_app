// Monkey (eventos aleatorios de Android) contra la app en el EMULADOR.
//
//   dart run tool/monkey.dart [--semillas 1,2,3] [--eventos 2000]
//       [--apk build/actualizacion/nueva.apk] [--compilar]
//       [--serial emulator-5554] [--env env/local-android.json]
//       [--env-pc env/local.json]
//
// Instala el build local (profile con env/local-android.json: llega al
// Supabase local por http) y, si la app está en el login, entra con el
// usuario de prueba de los tests de integración. Por cada semilla corre
//   adb shell monkey -p com.example.textiles_app --pct-syskeys 0
//       --throttle 100 -s <semilla> -v <eventos>
// y falla si el monkey informa un CRASH/ANR o logcat tiene un FATAL
// EXCEPTION / señal nativa / ANR de la app. Los errores de Dart que no tiran
// la app (excepción no manejada, error de un widget) se cuentan como aviso.
// Guarda la salida del monkey y el logcat de cada semilla en build/monkey/.
//
// Con la misma semilla y la misma pantalla de partida, el monkey repite la
// secuencia de eventos: así se reproduce una caída.
//
// ⚠️ El monkey toca de verdad: crea sucursales/telas/ventas con texto al
// azar, da de baja cosas y puede cerrar la sesión. Escribe en el Supabase
// LOCAL (se limpia con `npx supabase@latest db reset`); no correrlo mientras
// otro corre los tests de integración contra la misma base.
import 'dart:io';

import 'android_util.dart';

String _opcion(List<String> args, String nombre, String porDefecto) {
  final i = args.indexOf(nombre);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : porDefecto;
}

Future<void> main(List<String> args) => correrScript(() async {
      final serial = _opcion(args, '--serial', serialPorDefecto);
      final semillas = _opcion(args, '--semillas', '1,2,3')
          .split(',')
          .map((s) => int.parse(s.trim()))
          .toList();
      final eventos = int.parse(_opcion(args, '--eventos', '2000'));
      final env = File(_opcion(args, '--env', 'env/local-android.json'))
          .absolute
          .path;
      final envPc = _opcion(args, '--env-pc', 'env/local.json');
      var apk = _opcion(args, '--apk', 'build/actualizacion/nueva.apk');

      final salida = Directory(unir(raiz, unir('build', 'monkey')))
        ..createSync(recursive: true);
      final emulador = Emulador(serial);
      await emulador.verificarConectado();
      await emulador.despertar();
      final credenciales = Credenciales.deIntegracion();
      await asegurarUsuario(credenciales, envPc);

      if (args.contains('--compilar') || !File(apk).existsSync()) {
        paso('Compilando en profile');
        final codigo = await correrVisible(flutter,
            ['build', 'apk', '--profile', '--dart-define-from-file=$env'],
            dir: raiz);
        if (codigo != 0) throw const ErrorDeHerramienta('Falló la compilación');
        apk = unir(raiz, 'build/app/outputs/flutter-apk/app-profile.apk');
      }

      paso('Instalando $apk');
      try {
        await emulador.instalar(apk, reemplazar: true);
      } on ErrorDeHerramienta catch (e) {
        // Otra firma (p. ej. quedó un build debug con la clave oficial):
        // en el emulador se puede desinstalar y empezar de cero.
        if (!'$e'.contains('INSTALL_FAILED_UPDATE_INCOMPATIBLE')) rethrow;
        info('Firma distinta a la instalada: se desinstala primero');
        await emulador.desinstalar();
        await emulador.instalar(apk, reemplazar: false);
      }

      final avion = (await emulador.shell('settings get global airplane_mode_on')).trim();
      final resultados = <String>[];
      var fallo = false;
      for (final semilla in semillas) {
        paso('Semilla $semilla: $eventos eventos');
        // Misma pantalla de partida en cada semilla: la app recién abierta
        await emulador.cerrarApp();
        await emulador.despertar();
        await emulador.abrirApp();
        if (await iniciarSesionSiHaceFalta(emulador, credenciales)) {
          info('Sesión iniciada');
        }
        await emulador.limpiarLogcat();

        final inicio = DateTime.now();
        final ProcessResult r;
        try {
          r = await emulador.adb([
            'shell',
            'monkey',
            '-p',
            appId,
            '--pct-syskeys',
            '0',
            '--throttle',
            '100',
            '-s',
            '$semilla',
            '-v',
            '$eventos',
            // 100 ms por evento + margen: si el emulador se cae, no esperar
            // para siempre
          ], limite: Duration(seconds: eventos ~/ 10 + 300));
        } on ErrorDeHerramienta catch (e) {
          // ¿Se colgó la app o el emulador entero? Si ni `echo` responde, es
          // el emulador (pasó con la PC sin memoria: qemu queda congelado)
          final responde = await emulador
              .adb(['shell', 'echo', 'ok'], limite: const Duration(seconds: 15))
              .then((r) => '${r.stdout}'.contains('ok'))
              .catchError((Object _) => false);
          if (!responde) {
            resultados.add('semilla $semilla: SIN RESULTADO (el emulador dejó '
                'de responder: no es una caída de la app)');
            paso('Resultado (logs en ${salida.path})');
            resultados.forEach(info);
            return 2;
          }
          fallo = true;
          resultados.add('semilla $semilla: FALLA (el monkey no terminó: $e)');
          continue;
        }
        final duracion = DateTime.now().difference(inicio).inSeconds;
        final textoMonkey = '${r.stdout}${r.stderr}';
        // Se guarda antes de leer logcat: si el emulador se cae, queda esto
        File(unir(salida.path, 'semilla-$semilla.monkey.txt'))
            .writeAsStringSync(textoMonkey);
        final log = await emulador.logcat();
        File(unir(salida.path, 'semilla-$semilla.logcat.txt'))
            .writeAsStringSync(log);

        final problemas = <String>[
          for (final l in textoMonkey.split('\n'))
            if (l.contains('// CRASH') ||
                l.contains('NOT RESPONDING') ||
                l.contains('** Monkey aborted'))
              l.trim(),
          ...caidasEnLogcat(log),
        ];
        final inyectados = RegExp(r'Events injected: (\d+)')
                .firstMatch(textoMonkey)
                ?.group(1) ??
            '?';
        final errores = erroresDartEnLogcat(log);
        info('Eventos inyectados: $inyectados en $duracion s');
        if (errores.isNotEmpty) {
          info('Aviso: ${errores.length} errores de Dart en logcat, p. ej.:');
          for (final e in errores.toSet().take(5)) {
            info('  $e');
          }
        }
        if (problemas.isEmpty) {
          resultados.add('semilla $semilla: OK ($inyectados eventos)');
        } else {
          fallo = true;
          resultados.add('semilla $semilla: FALLA (${problemas.first})');
          for (final p in problemas.take(10)) {
            info('FALLA: $p');
          }
        }

        // El monkey puede haber activado el modo avión desde el panel de
        // notificaciones: se deja como estaba para la semilla siguiente
        final avionAhora =
            (await emulador.shell('settings get global airplane_mode_on')).trim();
        if (avionAhora != avion) {
          info('Aviso: el monkey cambió el modo avión ($avion → $avionAhora); '
              'se vuelve a dejar como estaba');
          await emulador.shell('cmd connectivity airplane-mode '
              '${avion == '1' ? 'enable' : 'disable'}');
        }
      }

      paso('Resultado (logs en ${salida.path})');
      for (final r in resultados) {
        info(r);
      }
      return fallo ? 1 : 0;
    });
