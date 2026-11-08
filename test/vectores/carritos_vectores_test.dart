import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/produccion_form_cubit.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/venta_apliques_form_cubit.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/detalle_venta_form_cubit.dart';

import '../helpers/fake_repositories.dart';
import 'vectores.dart';

/// `test/vectores/carritos.json` con los cubits de los tres carritos.
void main() {
  probarVectores('carritos', (caso) async {
    final e = caso.entrada;
    final productos = {
      for (final p in (e['productos'] as List).cast<Map<String, dynamic>>())
        p['id'] as int: p
    };
    final colores = {
      for (final c in ((e['colores'] as List?) ?? const <Object>[])
          .cast<Map<String, dynamic>>())
        c['id'] as int: c
    };
    final stock = {
      for (final s in ((e['stock'] as List?) ?? const <Object>[])
          .cast<Map<String, dynamic>>())
        (s['producto'] as int, s['color'] as int): (s['stock'] as num).toDouble()
    };
    final pasos = (e['pasos'] as List).cast<Map<String, dynamic>>();
    final resultados = <String?>[];

    switch (e['carrito']) {
      case 'telas':
        final cubit = DetalleVentaFormCubit(
            ventasRepository: FakeVentasRepository(), idsucursal: 1);
        addTearDown(cubit.close);
        for (final paso in pasos) {
          if (paso['quitar'] case final int i) {
            final l = cubit.state.detVentas[i];
            cubit.removeDetalleVenta(l['idtelas'] as int,
                (l['cantidad'] as num).toDouble(), (l['precio'] as num).toDouble());
          } else {
            final a = paso['agregar'] as Map<String, dynamic>;
            final p = productos[a['producto']];
            cubit
              ..onIdTelasChanged((p?['id'] as int?) ?? 0)
              ..onNombreChanged((p?['nombre'] as String?) ?? '')
              ..onPrecxCompraChanged(((p?['costo'] as num?) ?? 0).toDouble())
              ..onCantidadChanged(a['cantidad'] as String)
              ..onPrecioChanged(a['precio'] as String)
              ..addDetalleVenta();
          }
          resultados.add(null);
        }
        expectComoVector({
          'resultados': resultados,
          'lineas': [
            for (final l in cubit.state.detVentas)
              {
                'idtelas': l['idtelas'],
                'nombre': l['nombre'],
                'cantidad': l['cantidad'],
                'precio': l['precio'],
                'total': l['total'],
                'ganancias': l['ganancias'],
              },
          ],
          'total': cubit.state.total,
          'ganancias': cubit.state.ganancias,
        }, caso.esperado);

      case 'apliques':
        final cubit = VentaApliquesFormCubit(
            ventasApliquesRepository: FakeVentasApliquesRepository(),
            idsucursal: 1);
        addTearDown(cubit.close);
        for (final paso in pasos) {
          if (paso['quitar'] case final int i) {
            final l = cubit.state.detalles[i];
            cubit.removeDetalle(
                l['idapliques'] as int,
                l['idcolor'] as int,
                (l['cantidad'] as num).toDouble(),
                (l['precio'] as num).toDouble());
            resultados.add(null);
            continue;
          }
          final a = paso['agregar'] as Map<String, dynamic>;
          final p = productos[a['producto']];
          final c = colores[a['color']];
          cubit.onApliqueChanged(p == null
              ? null
              : Aplique(
                  id: p['id'] as int,
                  nombre: p['nombre'] as String,
                  costoFabricacion: (p['costo'] as num).toDouble()));
          cubit
            ..onColorChanged(c == null
                ? null
                : StockAplique(
                    apliqueId: (p?['id'] as int?) ?? 0,
                    colorId: c['id'] as int,
                    colorNombre: c['nombre'] as String,
                    hex: c['hex'] as String,
                    stock: stock[(p?['id'], c['id'])] ?? 0))
            ..onCantidadChanged(a['cantidad'] as String)
            ..onPrecioChanged(a['precio'] as String);
          resultados.add(cubit.addDetalle());
        }
        expectComoVector({
          'resultados': resultados,
          'lineas': [
            for (final l in cubit.state.detalles)
              {
                'idapliques': l['idapliques'],
                'idcolor': l['idcolor'],
                'nombre': l['nombre'],
                'cantidad': l['cantidad'],
                'precio': l['precio'],
                'total': l['total'],
                'ganancias': l['ganancias'],
              },
          ],
          'total': cubit.state.total,
          'ganancias': cubit.state.ganancias,
        }, caso.esperado);

      case 'fabricacion':
        final cubit = ProduccionFormCubit(
          apliquesRepository: FakeApliquesRepository(colores: [
            for (final c in colores.values)
              ColorItem(
                  id: c['id'] as int,
                  nombre: c['nombre'] as String,
                  hex: c['hex'] as String,
                  vinculado: true),
          ]),
          idsucursal: 1,
        );
        addTearDown(() async {
          await pumpEventQueue(); // load() del constructor
          await cubit.close();
        });
        for (final paso in pasos) {
          if (paso['quitar'] case final int i) {
            final l = cubit.state.detProducciones[i];
            cubit.removeDetalleProduccion(l['idaplique'] as int,
                l['idcolor'] as int, (l['cantidad'] as num).toDouble());
            resultados.add(null);
            continue;
          }
          final a = paso['agregar'] as Map<String, dynamic>;
          final p = productos[a['producto']];
          final c = colores[a['color']];
          await cubit.onApliqueChanged(p == null
              ? null
              : Aplique(id: p['id'] as int, nombre: p['nombre'] as String));
          cubit
            ..onColorChanged(c == null
                ? null
                : ColorItem(
                    id: c['id'] as int,
                    nombre: c['nombre'] as String,
                    hex: c['hex'] as String))
            ..onCantidadChanged(a['cantidad'] as String);
          resultados.add(cubit.addDetalleProduccion());
        }
        expectComoVector({
          'resultados': resultados,
          'lineas': [
            for (final l in cubit.state.detProducciones)
              {
                'idaplique': l['idaplique'],
                'apliqueNombre': l['apliqueNombre'],
                'idcolor': l['idcolor'],
                'colorNombre': l['colorNombre'],
                'hex': l['hex'],
                'cantidad': l['cantidad'],
              },
          ],
        }, caso.esperado);

      default:
        fail('carrito desconocido: ${e['carrito']}');
    }
  });
}
