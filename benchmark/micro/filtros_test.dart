@Tags(['benchmark'])
library;

// Micro-benchmarks del filtrado puro fuera de widgets y cubits:
// `ApliquesDatasourceImpl.soloColoresVinculados`, que deja del inventario de
// la sucursal solo los colores vinculados al aplique (`aplique_colores`
// activos). Lo usa `getStock` en cada apertura de la venta de apliques y de
// Fabricación, y recibe TODOS los vínculos activos (no solo los de la
// sucursal), así que [vinculos] suele ser más grande que [inventario].
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/infrastructure/datasources/apliques_datasource_impl.dart';

import 'medicion.dart';

/// Último resultado medido: que el compilador no pueda descartar el trabajo.
Object? sink;

void main() {
  grupoBenchmark('filtros', () {
    _soloColoresVinculados(inventario: 100, vinculos: 300, presupuestoUs: 700);
    _soloColoresVinculados(
        inventario: 1000, vinculos: 3000, presupuestoUs: 10000);
  });
}

/// [inventario] filas de `inventario` (10 colores por aplique) contra
/// [vinculos] filas de `aplique_colores`: de cada aplique quedan vinculados
/// los colores pares, así que pasa la mitad del inventario.
void _soloColoresVinculados({
  required int inventario,
  required int vinculos,
  required double presupuestoUs,
}) {
  final filasInventario = _comoSupabase([
    for (var i = 0; i < inventario; i++)
      {
        'aplique_id': i ~/ 10 + 1,
        'color_id': i % 10 + 1,
        'stock': i % 50,
        'colores': {'nombre': 'Color ${i % 10}', 'hex': '#FF8800'},
      }
  ]);
  // 5 colores vinculados (los pares) por aplique; también de apliques que
  // la sucursal no tiene en inventario.
  final filasVinculos = _comoSupabase([
    for (var i = 0; i < vinculos; i++)
      {'idaplique': i ~/ 5 + 1, 'idcolor': (i % 5) * 2 + 2},
  ]);

  microBenchmark(
    'ApliquesDatasourceImpl.soloColoresVinculados '
    'inventario $inventario + vínculos $vinculos',
    () => sink = ApliquesDatasourceImpl.soloColoresVinculados(
        filasInventario, filasVinculos),
    presupuestoUs: presupuestoUs,
    preparar: () {
      final filtrado = ApliquesDatasourceImpl.soloColoresVinculados(
          filasInventario, filasVinculos);
      expect(filtrado, hasLength(inventario ~/ 2));
      expect(filtrado.every((e) => (e['color_id'] as int).isEven), isTrue);
    },
  );
}

/// Las filas como las entrega supabase_flutter: pasadas por JSON y en una
/// `List<Map<String, dynamic>>`.
List<Map<String, dynamic>> _comoSupabase(List<Map<String, Object?>> filas) =>
    List<Map<String, dynamic>>.from(jsonDecode(jsonEncode(filas)) as List);
