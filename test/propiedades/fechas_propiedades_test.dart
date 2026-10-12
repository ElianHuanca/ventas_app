import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/changeFormatDate.dart';

import 'generadores.dart';

/// `changeFormatDate` (títulos de ventas y producciones) y la convención de
/// `fecha` como texto ISO8601: las RPC del dashboard y la búsqueda de la venta
/// del día comparan ese texto, así que su orden tiene que ser el cronológico.
void main() {
  propiedad(
      'changeFormatDate da día-mes-año sin ceros y se puede leer de '
      'vuelta',
      _instante(desde: 1, hasta: 10000), (fecha) {
    final texto = changeFormatDate(fecha);

    expect(texto, matches(RegExp(r'^[1-9]\d?-[1-9]\d?-[1-9]\d*$')));
    final [dia, mes, anio] = texto.split('-').map(int.parse).toList();
    expect((dia, mes, anio), (fecha.day, fecha.month, fecha.year));
  }, casos: 2000);

  propiedad('el texto ISO8601 se ordena igual que las fechas',
      any.combine2(_instante(), _instante(), (a, b) => (a, b)), (par) {
    final (a, b) = par;

    expect(a.toIso8601String().compareTo(b.toIso8601String()).sign,
        _comparar(a, b).sign,
        reason: '${a.toIso8601String()} vs ${b.toIso8601String()}');
  }, casos: 2000);

  propiedad(
      'todo instante del día cae entre el inicio y el fin del día como '
      'texto',
      _instante(), (fecha) {
    final texto = fecha.toIso8601String();
    final inicio = DateTime(fecha.year, fecha.month, fecha.day);
    // Como _finDelDia del dashboard: hasta el último microsegundo
    final fin =
        DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59, 999, 999);

    expect(texto.compareTo(inicio.toIso8601String()), greaterThanOrEqualTo(0));
    expect(texto.compareTo(fin.toIso8601String()), lessThanOrEqualTo(0));
    // getVentaByFecha busca la venta del día por este prefijo
    expect(texto.substring(0, 10), inicio.toIso8601String().substring(0, 10));
  }, casos: 2000);

  propiedad('toIso8601String y DateTime.parse van y vuelven sin perder nada',
      _instante(), (fecha) {
    final vuelta = DateTime.parse(fecha.toIso8601String());

    // Por campos y no por instante: con horario de verano una hora local
    // ambigua puede volver como el otro instante con la misma hora
    expect(_comparar(vuelta, fecha), 0, reason: '$vuelta vs $fecha');
    expect(vuelta.isUtc, isFalse);
  }, casos: 2000);
}

/// Un instante local entre los años [desde] y [hasta] (exclusivo), con
/// microsegundos (lo que guarda `DateTime.now().toIso8601String()`).
Generator<DateTime> _instante({int desde = 1000, int hasta = 10000}) =>
    any.combine8(
      any.entero(desde, hasta),
      any.entero(1, 13),
      any.entero(1, 32),
      any.entero(0, 24),
      any.entero(0, 60),
      any.entero(0, 60),
      any.entero(0, 1000),
      any.entero(0, 1000),
      (int anio, int mes, int dia, int hora, int minuto, int segundo, int ms,
          int us) {
        final diasDelMes = DateTime(anio, mes + 1, 0).day;
        return DateTime(anio, mes, dia > diasDelMes ? diasDelMes : dia, hora,
            minuto, segundo, ms, us);
      },
    );

/// Orden cronológico por campos (en hora local, como se guarda).
int _comparar(DateTime a, DateTime b) {
  final campos = [
    (a.year, b.year),
    (a.month, b.month),
    (a.day, b.day),
    (a.hour, b.hour),
    (a.minute, b.minute),
    (a.second, b.second),
    (a.millisecond, b.millisecond),
    (a.microsecond, b.microsecond),
  ];
  for (final (x, y) in campos) {
    if (x != y) return x.compareTo(y);
  }
  return 0;
}
