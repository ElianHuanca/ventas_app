/// Vectores de prueba compartidos entre los ports (Flutter, Android, iOS).
///
/// Cada `test/vectores/<tema>.json` es la **fuente de verdad**: casos
/// `{ "nombre", "entrada", "esperado" }` que cada port recorre con sus propias
/// funciones. Si un port da otra cosa con la misma entrada, hay una diferencia
/// de paridad. Android lee una copia (`tool/sincronizar_vectores.dart`).
///
/// Una diferencia **a propósito** (marcada en la spec del port con
/// `<!-- paridad: ... -->`) va en el caso como
/// `"difiere": { "android": { "esperado": ..., "paridad": "<spec>: ..." } }`:
/// ese port compara contra su `esperado` y el resto contra el común.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Un caso de un vector, con el `esperado` que le toca a Flutter.
class Caso {
  Caso(this.nombre, this.entrada, this.esperado);

  final String nombre;
  final Map<String, dynamic> entrada;
  final Object? esperado;

  @override
  String toString() => nombre;
}

/// Lee `test/vectores/<tema>.json` (las pruebas corren desde la raíz del
/// proyecto).
List<Caso> cargarVectores(String tema) {
  final json = jsonDecode(File('test/vectores/$tema.json').readAsStringSync())
      as Map<String, dynamic>;
  return [
    for (final c in (json['casos'] as List).cast<Map<String, dynamic>>())
      Caso(
        c['nombre'] as String,
        c['entrada'] as Map<String, dynamic>,
        // Flutter es la referencia: solo usaría un esperado propio si algún
        // día se marca una diferencia a propósito de este lado
        c.containsKey('difiere') &&
                (c['difiere'] as Map<String, dynamic>).containsKey('flutter')
            ? ((c['difiere'] as Map<String, dynamic>)['flutter']
                as Map<String, dynamic>)['esperado']
            : c['esperado'],
      ),
  ];
}

/// Un test por caso de `test/vectores/<tema>.json`.
///
/// [paridad]: casos en los que Flutter difiere de los otros ports sin que esté
/// marcado como diferencia a propósito (nombre → `'paridad: ...'`). Quedan
/// omitidos hasta que se resuelva la diferencia.
void probarVectores(
  String tema,
  FutureOr<void> Function(Caso caso) verificar, {
  Map<String, String> paridad = const {},
}) {
  final casos = cargarVectores(tema);
  test('el vector $tema tiene casos con nombres únicos', () {
    expect(casos, isNotEmpty);
    final nombres = casos.map((c) => c.nombre).toList();
    expect(nombres.toSet(), hasLength(nombres.length));
    expect(nombres, containsAll(paridad.keys),
        reason: 'cada diferencia de paridad apunta a un caso que existe');
  });
  for (final caso in casos) {
    test(caso.nombre, () => verificar(caso), skip: paridad[caso.nombre]);
  }
}

/// Compara un valor con el `esperado` del vector, recorriendo mapas y listas.
///
/// Los números se comparan por valor (5 == 5.0) pero distinguiendo el signo
/// del cero: `-0.0` no es `0.0` (un port que muestre "-0.0" difiere).
void expectComoVector(Object? actual, Object? esperado, {String donde = r'$'}) {
  if (esperado is Map) {
    expect(actual, isA<Map<dynamic, dynamic>>(), reason: donde);
    final a = actual! as Map<dynamic, dynamic>;
    expect(a.keys.toSet(), esperado.keys.toSet(), reason: '$donde: claves');
    for (final clave in esperado.keys) {
      expectComoVector(a[clave], esperado[clave], donde: '$donde.$clave');
    }
  } else if (esperado is List) {
    expect(actual, isA<List<dynamic>>(), reason: donde);
    final a = actual! as List<dynamic>;
    expect(a, hasLength(esperado.length), reason: '$donde: largo');
    for (var i = 0; i < esperado.length; i++) {
      expectComoVector(a[i], esperado[i], donde: '$donde[$i]');
    }
  } else if (esperado is num) {
    expect(actual, isA<num>(), reason: donde);
    final a = actual! as num;
    expect(a, esperado, reason: donde);
    if (esperado == 0) {
      expect(a.isNegative, esperado.isNegative,
          reason: '$donde: signo del cero ($a)');
    }
  } else {
    expect(actual, esperado, reason: donde);
  }
}

/// Una fecha-hora como la escriben los vectores: `aaaa-mm-ddThh:mm:ss.ffffff`
/// con los campos tal cual (sin pasar a hora local ni a UTC).
String fechaHoraDeVector(DateTime d) {
  String dos(int n) => n.toString().padLeft(2, '0');
  final micro =
      (d.millisecond * 1000 + d.microsecond).toString().padLeft(6, '0');
  return '${d.year.toString().padLeft(4, '0')}-${dos(d.month)}-${dos(d.day)}'
      'T${dos(d.hour)}:${dos(d.minute)}:${dos(d.second)}.$micro';
}

/// Marca de los vectores para "la fecha y hora actual" (lo que hace cada port
/// cuando la fecha no se puede leer, o cuando la arma con `now()`).
const ahora = '<ahora>';

/// Marca de los vectores para "el día de hoy" (una fecha-día que no se puede
/// leer).
const hoy = '<hoy>';

/// [d] es "ahora" (con un minuto de margen).
void expectAhora(DateTime d, {String donde = r'$'}) {
  expect(d.difference(DateTime.now()).inSeconds.abs(), lessThan(60),
      reason: '$donde: tendría que ser la fecha y hora actual, es $d');
}
