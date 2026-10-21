/// Varios "dispositivos" contra el Supabase local: un [SupabaseClient]
/// independiente por cada uno (su propia conexión HTTP y su propia sesión del
/// usuario de prueba) para lanzar la misma operación a la vez y ver qué deja
/// la base.
///
/// Escriben en la base, así que no corren con `flutter test` a secas:
///
/// ```bash
/// flutter test concurrencia --dart-define-from-file=env/local.json --concurrency=1
/// ```
///
/// No se inicializa `TestWidgetsFlutterBinding` (son `test()` simples): con él
/// flutter_test reemplaza el `HttpClient` y toda request devuelve 400.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:textiles_app/config/supabase/supabase_config.dart';

/// Mismo usuario que `integration_test/helpers.dart`. No se importa de ahí
/// porque arrastraría la app entera a cada archivo de estos tests.
const emailPrueba =
    String.fromEnvironment('IT_EMAIL', defaultValue: 'integracion@example.com');
const passwordPrueba = String.fromEnvironment('IT_PASSWORD',
    defaultValue: 'integracion-local-123');

/// Cuántas veces se repite cada escenario: con más vueltas es más probable
/// que las transacciones se crucen de verdad en la base.
const repeticiones = int.fromEnvironment('CC_REPETICIONES', defaultValue: 5);

/// Dispositivos que disparan la operación a la vez en cada escenario.
const cantidadDispositivos = 8;

/// Sesiones guardadas entre archivos y entre corridas. El Supabase local
/// acepta 30 inicios de sesión cada 5 minutos (`[auth.rate_limit]` en
/// `supabase/config.toml`) y ese cupo lo comparten todos los tests que corren
/// contra él: cada dispositivo inicia sesión una vez y reusa su sesión
/// mientras le queden más de 10 minutos. Está en `build/` (ignorado por git).
final _sesionesGuardadas = File('build/concurrencia/sesiones.json');

/// Corta con un mensaje claro si los tests no apuntan a la base local: sin
/// `--dart-define` `SupabaseConfig` apunta a producción.
void exigirBaseLocal() {
  if (!SupabaseConfig.isLocal) {
    throw StateError(
      'Los tests de concurrencia escriben en la base y solo corren contra el '
      'Supabase local. Correr con --dart-define-from-file=env/local.json '
      '(URL actual: ${SupabaseConfig.url}).',
    );
  }
}

/// Abre [cantidad] dispositivos, cada uno con su propia sesión del usuario de
/// prueba (si no existe en la base, lo crea con signUp, igual que
/// `_asegurarUsuarioDePrueba` de los tests de integración).
Future<List<SupabaseClient>> abrirDispositivos(
    [int cantidad = cantidadDispositivos]) async {
  exigirBaseLocal();
  final guardadas = _leerSesiones();
  final dispositivos = <SupabaseClient>[];
  try {
    for (var i = 0; i < cantidad; i++) {
      final dispositivo = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.publishableKey,
        // Sin el timer de refresco: una corrida dura mucho menos que el token.
        // Flujo implicit: el PKCE por defecto pide un asyncStorage para el
        // signUp, y en una base nueva (la CI) el usuario de prueba no existe.
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
      );
      dispositivos.add(dispositivo);
      final guardada = guardadas['$i'];
      if (guardada == null || !await _retomarSesion(dispositivo, guardada)) {
        await _iniciarSesion(dispositivo);
        guardadas['$i'] = jsonEncode(dispositivo.auth.currentSession!.toJson());
        _guardarSesiones(guardadas);
      }
    }
    await _verificarDispositivos(dispositivos);
  } catch (_) {
    await cerrarDispositivos(dispositivos);
    rethrow;
  }
  return dispositivos;
}

/// No cierra las sesiones (quedan guardadas para la próxima corrida): solo
/// libera los clientes.
Future<void> cerrarDispositivos(List<SupabaseClient> dispositivos) async {
  for (final dispositivo in dispositivos) {
    await dispositivo.dispose();
  }
}

/// Resultado de la operación de un dispositivo: lo que devolvió o su error.
class Resultado<T> {
  Resultado.ok(this.valor) : error = null;
  Resultado.falla(Object this.error) : valor = null;

  final T? valor;
  final Object? error;

  bool get ok => error == null;

  @override
  String toString() => ok ? 'ok($valor)' : 'error($error)';
}

/// Lanza [operacion] en todos los [dispositivos] a la vez (como si tocaran
/// "Registrar" en el mismo instante) y espera a que terminen todas, sin cortar
/// en el primer error: cada uno devuelve su [Resultado].
///
/// Todas esperan la misma largada para salir en el mismo ciclo del event loop.
Future<List<Resultado<T>>> aLaVez<T>(
  List<SupabaseClient> dispositivos,
  Future<T> Function(int i, SupabaseClient dispositivo) operacion,
) {
  final largada = Completer<void>();
  final enCurso = [
    for (var i = 0; i < dispositivos.length; i++)
      largada.future.then((_) => operacion(i, dispositivos[i])).then(
            Resultado<T>.ok,
            onError: (Object e) => Resultado<T>.falla(e),
          ),
  ];
  largada.complete();
  return Future.wait(enCurso);
}

Future<void> _iniciarSesion(SupabaseClient dispositivo) async {
  final auth = dispositivo.auth;
  try {
    await auth.signInWithPassword(email: emailPrueba, password: passwordPrueba);
  } on AuthException catch (e) {
    if (e.statusCode == '429') {
      throw StateError(
        'Se agotó el cupo de inicios de sesión del Supabase local (30 cada 5 '
        'minutos, [auth.rate_limit] en supabase/config.toml). Esperar unos '
        'minutos y volver a correr.',
      );
    }
    // Primera corrida contra esta base (o después de un `db reset`). El
    // registro público solo está habilitado en el Supabase local.
    await auth.signUp(email: emailPrueba, password: passwordPrueba);
  }
  if (auth.currentSession == null) {
    throw StateError('No se pudo iniciar sesión con $emailPrueba en '
        '${SupabaseConfig.url}.');
  }
}

/// Retoma una sesión guardada si le quedan más de 10 minutos y la base la
/// acepta.
Future<bool> _retomarSesion(SupabaseClient dispositivo, String guardada) async {
  try {
    final sesion =
        Session.fromJson(jsonDecode(guardada) as Map<String, dynamic>);
    final vence = sesion?.expiresAt;
    if (vence == null) return false;
    final quedan = DateTime.fromMillisecondsSinceEpoch(vence * 1000)
        .difference(DateTime.now());
    if (quedan < const Duration(minutes: 10)) return false;
    await dispositivo.auth.recoverSession(guardada);
    await dispositivo.from('sucursales').select('id').limit(1);
    return true;
  } catch (_) {
    // Guardada inválida o rechazada por la base: se inicia sesión de nuevo.
    return false;
  }
}

/// Cada dispositivo tiene una sesión distinta (otro `session_id` en el JWT),
/// logueada, y sus requests llegan de verdad a la base (con el `HttpClient`
/// falso de flutter_test, o sin sesión, este select falla).
Future<void> _verificarDispositivos(List<SupabaseClient> dispositivos) async {
  final claims = [
    for (final d in dispositivos) _claims(d.auth.currentSession!.accessToken),
  ];
  if (claims.any((c) => c['role'] != 'authenticated')) {
    throw StateError('Hay dispositivos sin sesión de usuario: $claims');
  }
  final sesiones = claims.map((c) => c['session_id']).toSet();
  if (sesiones.length != dispositivos.length) {
    throw StateError('Los dispositivos comparten sesión: $sesiones');
  }
  await Future.wait(
      dispositivos.map((d) => d.from('sucursales').select('id').limit(1)));
}

Map<String, dynamic> _claims(String jwt) {
  final payload = base64Url.normalize(jwt.split('.')[1]);
  return jsonDecode(utf8.decode(base64Url.decode(payload)))
      as Map<String, dynamic>;
}

Map<String, String> _leerSesiones() {
  try {
    return Map<String, String>.from(
        jsonDecode(_sesionesGuardadas.readAsStringSync()) as Map);
  } catch (_) {
    // No existe todavía o quedó corrupto: se inicia sesión de nuevo.
    return {};
  }
}

void _guardarSesiones(Map<String, String> sesiones) {
  _sesionesGuardadas.parent.createSync(recursive: true);
  _sesionesGuardadas.writeAsStringSync(jsonEncode(sesiones), flush: true);
}
