/// "El celular" de los tests de red: la app con su cliente de Supabase de
/// siempre (`SupabaseConfig.client`, el que usan todos los datasources) pero
/// con la red en [RedConFallas], más un cliente sano para preparar datos y
/// mirar qué quedó en la base.
///
/// Escriben en la base, así que no corren con `flutter test` a secas:
///
/// ```bash
/// flutter test red --dart-define-from-file=env/local.json --concurrency=1
/// ```
///
/// Como en `concurrencia/`, son `test()` simples: `TestWidgetsFlutterBinding`
/// reemplaza el `HttpClient` y toda request devolvería 400. Sí se inicializa
/// el binding real (`WidgetsFlutterBinding`), que no toca la red:
/// `Supabase.initialize` lo necesita para escuchar el ciclo de vida de la app.
library;

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:textiles_app/config/supabase/supabase_config.dart';

import '../concurrencia/datos.dart';
import '../concurrencia/dispositivos.dart';
import 'red_con_fallas.dart';

/// Fecha de las ventas y producciones de estos tests: un día de 2001, fuera
/// del rango por defecto del dashboard (este mes) y del de los tests de
/// integración (enero de 2020). Cada test usa una sucursal nueva, así que su
/// venta y su producción del día son solo suyas. Distinta de la de
/// `concurrencia/` (2001-01-01) para distinguirlas en Studio.
final fechaRD = DateTime(2001, 1, 2, 12);

/// Los tests omitidos son bugs conocidos (`skip:` con su `// bug:`). Con
/// `--dart-define=RED_CORRER_BUGS=true` corren igual, para ver que siguen
/// fallando (o, al arreglarlos, que ya pasan y hay que sacarles el skip).
const bugConocido = !bool.fromEnvironment('RED_CORRER_BUGS');

class Celular {
  Celular._(this.red, this.base);

  /// La red por la que salen los pedidos de la app.
  final RedConFallas red;

  /// Cliente sano (otra sesión del mismo usuario) para preparar datos y
  /// verificar la base sin pasar por las fallas.
  final SupabaseClient base;

  /// Inicializa `Supabase.instance` (de donde lee `SupabaseConfig.client`)
  /// con la misma URL y clave que `SupabaseConfig.init()`, pero con
  /// [RedConFallas] como `httpClient`. Los datasources se crean después de
  /// esto, así que todos salen por esta red.
  ///
  /// Las sesiones las reusa de `concurrencia/` (dos de sus dispositivos): el
  /// auth local acepta 30 inicios de sesión cada 5 minutos.
  static Future<Celular> abrir() async {
    exigirBaseLocal();
    WidgetsFlutterBinding.ensureInitialized();
    final dispositivos = await abrirDispositivos(2);
    final red = RedConFallas();
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        httpClient: red,
        debug: false,
        // Sin shared_preferences ni deep links (no hay plugins en el test) y
        // sin el timer de refresco: la sesión la trae el dispositivo 1.
        authOptions: FlutterAuthClientOptions(
          autoRefreshToken: false,
          localStorage: const EmptyLocalStorage(),
          pkceAsyncStorage: _PkceEnMemoria(),
          detectSessionInUri: false,
        ),
      );
      await SupabaseConfig.client.auth.recoverSession(
          jsonEncode(dispositivos[1].auth.currentSession!.toJson()));
    } catch (_) {
      await cerrarDispositivos(dispositivos);
      rethrow;
    }
    await cerrarDispositivos([dispositivos[1]]);

    // Los pedidos de SupabaseConfig.client pasan por la red con fallas y
    // llegan a la base con la sesión del usuario.
    await SupabaseConfig.client.from('sucursales').select('id').limit(1);
    if (red.entregadas.isEmpty ||
        SupabaseConfig.client.auth.currentSession == null) {
      throw StateError('SupabaseConfig.client no sale por RedConFallas');
    }
    red.registro.clear();
    return Celular._(red, dispositivos[0]);
  }

  Future<void> cerrar() async {
    await Supabase.instance.dispose();
    await cerrarDispositivos([base]);
  }
}

/// Datos con el prefijo `RD ` (los de `concurrencia/` llevan `CC `). La base
/// no permite borrarlos: se limpian con `npx supabase@latest db reset`.
class DatosRD extends DatosCC {
  DatosRD(super.db);

  final _sufijo = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  var _contador = 0;

  @override
  String nombre(String base) => 'RD $base $_sufijo-${_contador++}';
}

class _PkceEnMemoria extends GotrueAsyncStorage {
  final _items = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> removeItem({required String key}) async => _items.remove(key);

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _items[key] = value;
}

/// Suma en centavos de una columna de varias filas.
int sumaCentavos(List<Map<String, dynamic>> filas, String columna) =>
    filas.fold(0, (suma, f) => suma + centavos(f[columna]));
