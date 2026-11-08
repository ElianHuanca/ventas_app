import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/sucursales/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/telas/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/ventas/infrastructure/infrastructure.dart';

import 'vectores.dart';

/// `test/vectores/mappers.json` con los `*Mapper.jsonToEntity` de Flutter.
void main() {
  probarVectores('mappers', (caso) {
    final fila = caso.entrada['fila'] as Map<String, dynamic>;
    final esperado = caso.esperado! as Map<String, dynamic>;
    final DateTime? fecha;
    final Map<String, Object?> entidad;

    switch (caso.entrada['mapper']) {
      case 'venta':
        final v = VentaMapper.jsonToEntity(fila);
        fecha = v.fecha;
        entidad = {
          'id': v.id,
          'fecha': fechaHoraDeVector(v.fecha),
          'total': v.total,
          'ganancias': v.ganancias,
          'descuento': v.descuento,
          'idsucursales': v.idsucursales,
        };
      case 'detalle_venta':
        final d = DetalleVentaMapper.jsonToEntity(fila);
        fecha = null;
        entidad = {
          'id': d.id,
          'nombre': d.nombre,
          'precio': d.precio,
          'cantidad': d.cantidad,
          'total': d.total,
          'ganancias': d.ganancias,
          'idtelas': d.idtelas,
        };
      case 'tela':
        final t = TelaMapper.jsonToEntity(fila);
        fecha = null;
        entidad = {
          'id': t.id,
          'nombre': t.nombre,
          'precxmen': t.precxmen,
          'precxmay': t.precxmay,
          'precxrollo': t.precxrollo,
          'precxcompra': t.precxcompra,
          'activo': t.activo,
        };
      case 'sucursal':
        final s = SucursalMapper.jsonToEntity(fila);
        fecha = null;
        entidad = {'id': s.id, 'nombre': s.nombre};
      case 'tela_sucursal':
        final t = TelaSucursalMapper.jsonToEntity(fila);
        fecha = null;
        entidad = {
          'idtela': t.idtela,
          'nombre': t.nombre,
          'disponible': t.disponible,
        };
      case 'aplique':
        final a = ApliqueMapper.jsonToEntity(fila);
        fecha = null;
        entidad = {
          'id': a.id,
          'nombre': a.nombre,
          'costo_fabricacion': a.costoFabricacion,
          'tamanio': a.tamanio,
          'ancho_cm': a.anchoCm,
          'alto_cm': a.altoCm,
          'activo': a.activo,
        };
      case 'stock_aplique':
        final s = StockApliqueMapper.jsonToEntity(fila);
        fecha = null;
        entidad = {
          'aplique_id': s.apliqueId,
          'color_id': s.colorId,
          'color': s.colorNombre,
          'hex': s.hex,
          'stock': s.stock,
        };
      case 'stock_con_ventas':
        final s = StockConVentasMapper.jsonToEntity(fila);
        fecha = null;
        entidad = {
          'aplique_id': s.apliqueId,
          'aplique': s.aplique,
          'color_id': s.colorId,
          'color': s.color,
          'hex': s.hex,
          'stock': s.stock,
          'vendidas': s.vendidas,
          'vendidas_otras': s.vendidasOtras,
        };
      case 'produccion':
        final p = ProduccionMapper.jsonToEntity(fila);
        fecha = null;
        entidad = {
          'id': p.id,
          'fecha': p.fecha,
          'sucursal': p.sucursalNombre,
          'aplique': p.apliqueNombre,
          'color': p.colorNombre,
          'hex': p.hex,
          'cantidad': p.cantidad,
        };
      case 'produccion_cabecera':
        final p = ProduccionMapper.jsonToCabecera(fila);
        fecha = p.fecha;
        // La cabecera es de un día (columna date): se compara el día
        entidad = {'id': p.id, 'fecha': fechaHoraDeVector(p.fecha).substring(0, 10)};
      case 'venta_aplique':
        final v = VentaApliqueMapper.jsonToVentaAplique(fila);
        fecha = v.fecha;
        entidad = {'id': v.id, 'fecha': fechaHoraDeVector(v.fecha)};
      case 'detalle_venta_aplique':
        final d = VentaApliqueMapper.jsonToDetalle(fila);
        fecha = null;
        entidad = {
          'id': d.id,
          'nombre': d.nombre,
          'cantidad': d.cantidad,
          'precio': d.precio,
          'total': d.total,
        };
      default:
        fail('mapper desconocido: ${caso.entrada['mapper']}');
    }

    if (esperado['fecha'] == ahora) {
      expectAhora(fecha!, donde: 'fecha');
      entidad['fecha'] = ahora;
    } else if (esperado['fecha'] == hoy) {
      expect(entidad['fecha'], fechaHoraDeVector(DateTime.now()).substring(0, 10),
          reason: 'fecha: tendría que ser hoy');
      entidad['fecha'] = hoy;
    }
    expectComoVector(entidad, esperado);
  });
}
