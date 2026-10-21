import 'reposicion.dart';

/// Texto para mandarle al fabricante por WhatsApp: qué hacer para una
/// sucursal, en el orden de [faltantes] (el más urgente primero).
/// `*texto*` es negrita en WhatsApp.
String mensajeFaltantes({
  required String sucursal,
  required DateTime fecha,
  required List<Reposicion> faltantes,
}) {
  final dia = '${fecha.day.toString().padLeft(2, '0')}/'
      '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  final total = faltantes.fold<int>(0, (suma, r) => suma + r.hacer);
  return [
    '*Huantex – Faltantes $sucursal* ($dia)',
    '',
    // Entre paréntesis: es UNA línea partida en dos strings, no una coma que
    // falta (no_adjacent_strings_in_list)
    for (final r in faltantes)
      ('• ${r.item.aplique} – ${r.item.color}: hacer *${r.hacer}* '
          '(quedan ${cantidadLegible(r.item.stock)})'),
    '',
    'Total a hacer: $total',
  ].join('\n');
}

/// 12 / 2.5: el stock puede tener decimales.
String cantidadLegible(double c) =>
    c == c.roundToDouble() ? c.toStringAsFixed(0) : c.toStringAsFixed(2);
