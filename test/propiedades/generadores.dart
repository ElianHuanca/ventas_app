/// Base de los tests property-based (`test/propiedades/`): en vez de casos
/// puntuales, cada propiedad se verifica con cientos de entradas generadas
/// con [glados](https://pub.dev/packages/glados).
///
/// - **Determinísticas**: todas parten de [semilla]. Para explorar otras
///   entradas: `flutter test test/propiedades --dart-define=PROPIEDADES_SEMILLA=7`;
///   para una corrida más profunda (más casos por propiedad):
///   `--dart-define=PROPIEDADES_FACTOR=10`.
/// - **Reproducibles**: si una falla, glados achica la entrada hasta la mínima
///   que la sigue rompiendo y la imprime (`Failing for input: ...`); el nombre
///   del test lleva la semilla con la que se generó.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
// Solo la API de generadores: test/expect/group salen de flutter_test (glados
// re-exporta los de package:test y chocarían).
import 'package:glados/glados.dart'
    show
        Any,
        AnyUtils,
        BoolAny,
        CombinableAny,
        ExploreConfig,
        Generator,
        GeneratorUtils,
        Glados;

export 'package:glados/glados.dart'
    show
        Any,
        AnyUtils,
        BoolAny,
        CombinableAny,
        Generator,
        GeneratorUtils,
        IntAnys,
        ListAnys,
        StringAnys,
        any;

const semilla =
    int.fromEnvironment('PROPIEDADES_SEMILLA', defaultValue: 20261011);
const _factorCasos = int.fromEnvironment('PROPIEDADES_FACTOR', defaultValue: 1);

/// Declara un test que verifica [cuerpo] para [casos] entradas de
/// [entradas]. El cuerpo falla con `expect` como cualquier test.
void propiedad<T>(
  String descripcion,
  Generator<T> entradas,
  FutureOr<void> Function(T entrada) cuerpo, {
  int casos = 500,
  Object? skip,
}) {
  Glados<T>(
    entradas,
    ExploreConfig(numRuns: casos * _factorCasos, random: Random(semilla)),
  ).test('$descripcion [semilla $semilla]', cuerpo, skip: skip);
}

/// Un número con hasta 2 decimales tal como lo tipea el usuario: `12`,
/// `12.5`, `12.50`. Se guarda en centésimos para calcular lo esperado con
/// enteros, sin coma flotante.
class Decimal {
  const Decimal(this.centesimos, [this.conCeros = false]);

  final int centesimos;

  /// `12.50` en vez de `12.5` (y `12.00` en vez de `12`).
  final bool conCeros;

  /// El double que resulta de parsear [texto].
  double get valor => centesimos / 100;

  String get texto {
    final signo = centesimos < 0 ? '-' : '';
    final abs = centesimos.abs();
    final entero = abs ~/ 100;
    final resto = abs % 100;
    if (conCeros) return '$signo$entero.${resto.toString().padLeft(2, '0')}';
    if (resto == 0) return '$signo$entero';
    if (resto % 10 == 0) return '$signo$entero.${resto ~/ 10}';
    return '$signo$entero.${resto.toString().padLeft(2, '0')}';
  }

  @override
  String toString() => texto;
}

extension GeneradoresDelDominio on Any {
  /// Entero entre [min] (inclusive) y [max] (exclusivo). A diferencia de
  /// `intInRange`, que achica de a 1 (con rangos grandes una falla tardaría
  /// minutos en llegar a la entrada mínima), prueba primero [min] y después
  /// se acerca al valor a saltos que se achican a la mitad.
  Generator<int> entero(int min, int max) => simple(
        generate: (random, size) => min + random.nextInt(max - min),
        shrink: (n) sync* {
          if (n == min) return;
          yield min;
          for (var salto = (n - min) ~/ 2; salto > 0; salto ~/= 2) {
            yield n - salto;
          }
        },
      );

  /// Decimal entre [min] (inclusive) y [max] (exclusivo), en centésimos.
  Generator<Decimal> decimal(int min, int max) =>
      combine2(entero(min, max), this.bool, Decimal.new);

  /// Unidades (apliques, stock): casi siempre enteras, a veces con decimales.
  Generator<Decimal> unidades(int min, int max) => either(
        entero(min, max).map((u) => Decimal(u * 100)),
        decimal(min * 100, max * 100),
      );

  /// Un monto que puede ser 0 (precio de compra o costo sin cargar).
  Generator<Decimal> montoOCero(int max) =>
      either(always(const Decimal(0)), decimal(1, max));
}

/// Un monto con a lo sumo 2 decimales, sin ruido de coma flotante (el
/// double más cercano al valor en centavos, como `30.3` y no
/// `30.299999999999997`).
const Matcher esMontoEnCentavos = _EsMontoEnCentavos();

class _EsMontoEnCentavos extends Matcher {
  const _EsMontoEnCentavos();

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) =>
      item is num && item.isFinite && item == (item * 100).round() / 100;

  @override
  Description describe(Description description) => description
      .add('un monto con a lo sumo 2 decimales (sin ruido de coma flotante)');
}

/// Centavos de un monto que ya cumple [esMontoEnCentavos].
int centavos(num monto) => (monto * 100).round();

/// Redondeo comercial (mitad hacia afuera, como `double.round` y `numeric`
/// de Postgres) de un valor exacto en diezmilésimos a centavos.
int diezmilesimosACentavos(int diezmilesimos) => diezmilesimos >= 0
    ? (diezmilesimos + 50) ~/ 100
    : -((-diezmilesimos + 50) ~/ 100);
