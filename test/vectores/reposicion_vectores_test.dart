import 'package:textiles_app/features/apliques/domain/domain.dart';

import 'vectores.dart';

/// `test/vectores/reposicion.json` con `ReglaReposicion.aplicar`.
void main() {
  probarVectores('reposicion', (caso) {
    final inventario = [
      for (final (i, f)
          in (caso.entrada['inventario'] as List).cast<Map<String, dynamic>>().indexed)
        StockConVentas(
          apliqueId: i + 1,
          aplique: f['aplique'] as String,
          colorId: i + 1,
          color: f['color'] as String,
          hex: '',
          stock: (f['stock'] as num).toDouble(),
          vendidas: (f['vendidas'] as num).toDouble(),
          vendidasOtras: (f['vendidas_otras'] as num).toDouble(),
        ),
    ];

    final resultado = ReglaReposicion.aplicar(inventario);

    expectComoVector([
      for (final r in resultado)
        {
          'aplique': r.item.aplique,
          'color': r.item.color,
          'estimada': r.estimada,
          'por_semana': r.porSemana,
          'minimo': r.minimo,
          'hacer': r.hacer,
          'faltante': r.faltante,
          'semanas_de_stock':
              r.semanasDeStock.isInfinite ? null : r.semanasDeStock,
        },
    ], caso.esperado);
  });
}
