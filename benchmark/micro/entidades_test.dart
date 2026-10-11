@Tags(['benchmark'])
library;

// Micro-benchmarks de la poca lógica que tienen las entidades de dominio:
// `DetalleVenta.toJson` (la única entidad -> JSON), `TelaSucursal.copyWith`
// (lo usa la disponibilidad de telas por sucursal al tildar una tela) y los
// constructores `empty()` (formularios de alta).
//
// Ninguna entidad sobreescribe ==/hashCode ni tiene getters calculados.
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';

import 'medicion.dart';

/// Último resultado medido: que el compilador no pueda descartar el trabajo.
Object? sink;

void main() {
  grupoBenchmark('entidades', () {
    // --- DetalleVenta.toJson ---
    final detalles = [
      for (var i = 0; i < 1000; i++)
        DetalleVenta(
          id: i + 1,
          nombre: 'Tela $i',
          precio: 35.5 + i,
          cantidad: i % 2 == 0 ? 2 : 1.5,
          total: (35.5 + i) * (i % 2 == 0 ? 2 : 1.5),
          ganancias: 10.0 + i,
          idtelas: i + 1,
        )
    ];
    final cien = detalles.sublist(0, 100);

    microBenchmark(
      'DetalleVenta.toJson x1',
      () => sink = detalles.first.toJson(),
      presupuestoUs: 7,
      preparar: () => expect(detalles.first.toJson(), {
        'id': 1,
        'nombre': 'Tela 0',
        'precio': 35.5,
        'cantidad': 2.0,
        'total': 71.0,
        'idtelas': 1,
        'ganancias': 10.0,
      }),
    );
    microBenchmark(
      'DetalleVenta.toJson x100',
      () => sink = cien.map((d) => d.toJson()).toList(),
      presupuestoUs: 1000,
    );
    microBenchmark(
      'DetalleVenta.toJson x1000',
      () => sink = detalles.map((d) => d.toJson()).toList(),
      presupuestoUs: 10000,
    );

    // --- TelaSucursal.copyWith ---
    final telas = [
      for (var i = 0; i < 1000; i++)
        TelaSucursal(idtela: i + 1, nombre: 'Tela $i', disponible: i.isEven)
    ];
    microBenchmark(
      'TelaSucursal.copyWith x1',
      () => sink = telas.first.copyWith(disponible: false),
      presupuestoUs: 0.2,
      preparar: () {
        final copia = telas.first.copyWith(disponible: false);
        expect(copia.idtela, 1);
        expect(copia.nombre, 'Tela 0');
        expect(copia.disponible, isFalse);
      },
    );
    microBenchmark(
      'TelaSucursal.copyWith x1000',
      () => sink =
          telas.map((t) => t.copyWith(disponible: !t.disponible)).toList(),
      presupuestoUs: 500,
    );

    // --- empty() de los formularios de alta ---
    microBenchmark(
      'Tela.empty',
      () => sink = Tela.empty(),
      presupuestoUs: 0.2,
      preparar: () => expect(Tela.empty().id, 0),
    );
    microBenchmark(
      'Aplique.empty',
      () => sink = Aplique.empty(),
      presupuestoUs: 0.2,
      preparar: () => expect(Aplique.empty().id, 0),
    );
    microBenchmark(
      'Sucursal.empty',
      () => sink = Sucursal.empty(),
      presupuestoUs: 0.2,
      preparar: () => expect(Sucursal.empty().id, 0),
    );
  });
}
