import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/venta_apliques_form_cubit.dart';

import '../helpers/fake_repositories.dart';
import 'vectores.dart';

/// `test/vectores/redondeo.json`. En Flutter el redondeo (`_centavos`,
/// `_sinRuido`) y la lectura de lo tipeado (`double.tryParse` + `isFinite`)
/// son privados de cada carrito: se recorren por el carrito de venta de
/// apliques, con stock de sobra.
void main() {
  probarVectores('redondeo', (caso) async {
    final e = caso.entrada;
    final repo = FakeVentasApliquesRepository();
    final cubit = VentaApliquesFormCubit(
        ventasApliquesRepository: repo, idsucursal: 1);
    addTearDown(cubit.close);

    String? agregar(String cantidad, String precio, {double costo = 0}) {
      cubit
        ..onApliqueChanged(
            Aplique(id: 1, nombre: 'Flor', costoFabricacion: costo))
        ..onColorChanged(const StockAplique(
            apliqueId: 1,
            colorId: 1,
            colorNombre: 'Rojo',
            hex: 'C0392B',
            stock: 1e9))
        ..onCantidadChanged(cantidad)
        ..onPrecioChanged(precio);
      return cubit.addDetalle();
    }

    switch (e['tipo']) {
      case 'linea':
        expect(
            agregar(e['cantidad'] as String, e['precio'] as String,
                costo: (e['costo'] as num).toDouble()),
            isNull);
        final linea = cubit.state.detalles.single;
        expectComoVector(
            {'total': linea['total'], 'ganancias': linea['ganancias']},
            caso.esperado);
      case 'acumulado':
        for (final cantidad in (e['cantidades'] as List).cast<String>()) {
          expect(agregar(cantidad, e['precio'] as String), isNull);
        }
        final linea = cubit.state.detalles.single;
        expectComoVector(
            {'cantidad': linea['cantidad'], 'total': linea['total']},
            caso.esperado);
      case 'texto':
        final texto = e['texto'] as String;
        // Como cantidad: si se agrega, es el número leído
        final error = agregar(texto, '1');
        if (error == null) {
          expectComoVector(cubit.state.detalles.single['cantidad'], caso.esperado);
        } else if (error == 'Ingrese una cantidad válida') {
          expect(caso.esperado, isNull, reason: 'Flutter no lo leyó como número');
        } else {
          // Se leyó pero no es mayor a 0: el valor exacto se ve como
          // descuento (lo único que admite ceros y negativos)
          expect(error, 'La cantidad debe ser mayor a 0');
          expect(agregar('1', '1000000'), isNull);
          cubit.onDescuentoChanged(texto);
          expect(await cubit.onFormSubmit(), isTrue);
          expectComoVector(repo.lastDescuento, caso.esperado);
        }
      default:
        fail('tipo desconocido: ${e['tipo']}');
    }
  });
}
