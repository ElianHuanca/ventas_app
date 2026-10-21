import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/config/router/app_router.dart';
import 'package:textiles_app/features/auth/auth.dart';

import 'generadores.dart';

/// El redirect por sesión para cualquier ruta registrada en el router real
/// (con parámetros, query y barra final generados): sin sesión todo termina
/// en /login; con sesión nunca se queda en /login.
void main() {
  final rutas = _rutasRegistradas();
  final ubicaciones = _ubicacion(rutas);

  test('el router tiene rutas registradas (incluida /login)', () {
    expect(rutas, contains(rutaLogin));
    expect(rutas.length, greaterThan(1));
  });

  group('redireccionPorSesion', () {
    propiedad('sin sesión siempre va a /login, salvo desde /login', ubicaciones,
        (ubicacion) {
      expect(
        redireccionPorSesion(haySesion: false, ubicacion: ubicacion.camino),
        ubicacion.camino == rutaLogin ? isNull : rutaLogin,
      );
    }, casos: 1000);

    propiedad(
        'con sesión nunca queda en /login: de ahí va al inicio y el '
        'resto no se toca',
        ubicaciones, (ubicacion) {
      expect(
        redireccionPorSesion(haySesion: true, ubicacion: ubicacion.camino),
        ubicacion.camino == rutaLogin ? '/' : isNull,
      );
    }, casos: 1000);
  });

  group('el redirect del router real (createAppRouter)', () {
    final sesion = _Sesion();
    late GoRouter router;

    setUpAll(() => router = createAppRouter(authRepository: sesion));
    tearDownAll(() => router.dispose());

    /// Lo que resuelve GoRouter al navegar a [ubicacion]: el match y todos
    /// los redirects encadenados.
    Future<RouteMatchList> resolver(String ubicacion) async =>
        router.configuration.redirect(
          _ContextoFalso(),
          router.configuration.findMatch(ubicacion),
          redirectHistory: [],
        );

    propiedad(
        'sin sesión cualquier ruta registrada termina en /login', ubicaciones,
        (ubicacion) async {
      sesion.haySesion = false;

      final destino = await resolver(ubicacion.texto);

      expect(destino.isError, isFalse);
      expect(destino.uri.path, rutaLogin);
    }, casos: 1000);

    propiedad(
        'con sesión ninguna termina en /login y las demás quedan donde '
        'estaban',
        ubicaciones, (ubicacion) async {
      sesion.haySesion = true;

      final destino = await resolver(ubicacion.texto);

      expect(destino.isError, isFalse);
      expect(destino.uri.path, isNot(rutaLogin));
      if (ubicacion.camino != rutaLogin) {
        expect(destino.uri.path, ubicacion.camino);
        expect(destino.uri.query, ubicacion.query);
      }
    }, casos: 1000);
  });
}

List<String> _rutasRegistradas() {
  final router = createAppRouter(authRepository: _Sesion());
  try {
    return router.configuration.routes
        .whereType<GoRoute>()
        .map((r) => r.path)
        .toList();
  } finally {
    router.dispose();
  }
}

/// Sesión que el test prende y apaga a mano.
class _Sesion implements AuthRepository {
  @override
  bool haySesion = false;

  @override
  String? get email => haySesion ? 'dueno@huantex.com' : null;

  @override
  Stream<bool> get cambiosDeSesion => const Stream.empty();

  @override
  Future<void> iniciarSesion(
          {required String email, required String password}) async =>
      haySesion = true;

  @override
  Future<void> cerrarSesion() async => haySesion = false;
}

/// El redirect de la app no usa el contexto.
class _ContextoFalso extends Fake implements BuildContext {}

class _Ubicacion {
  _Ubicacion(this.camino, this.query, {required this.barraFinal});

  /// La ruta con los parámetros reemplazados (lo que el redirect recibe
  /// como `matchedLocation`).
  final String camino;
  final String query;
  final bool barraFinal;

  String get texto => [
        camino,
        if (barraFinal && camino != '/') '/',
        if (query.isNotEmpty) '?$query',
      ].join();

  @override
  String toString() => texto;
}

const _valores = ['0', '1', '7', '42', '999999', 'abc', 'x-1', '_'];
const _queries = ['', 'fecha=2026-10-05', 'fecha=', 'a=1&b=2'];

Generator<_Ubicacion> _ubicacion(List<String> rutas) => any.combine4(
      any.choose(rutas),
      any.listWithLength(3, any.entero(0, _valores.length)),
      any.entero(0, _queries.length),
      any.bool,
      (String ruta, List<int> valores, int query, bool barraFinal) {
        var i = 0;
        final camino = ruta.replaceAllMapped(
            RegExp(r':\w+'), (_) => _valores[valores[i++ % valores.length]]);
        return _Ubicacion(camino, _queries[query], barraFinal: barraFinal);
      },
    );
