@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';

import '../concurrencia/datos.dart';
import 'celular.dart';
import 'red_con_fallas.dart';

/// Fabricación con la red cortándose: `ProduccionFormCubit` →
/// `ApliquesDatasourceImpl.createProduccion` → RPC `registrar_produccion`,
/// y después `getStock` para refrescar la pantalla. Mismos objetos que la
/// ruta `/fabricacion/registro/:idsucursal`, con la fecha elegida en el
/// formulario ([fechaRD], como "fecha anterior").
void main() {
  late Celular celular;
  late DatosRD datos;
  RedConFallas red() => celular.red;

  setUpAll(() async {
    celular = await Celular.abrir();
    datos = DatosRD(celular.base);
  });

  tearDownAll(() async {
    try {
      await datos.darDeBaja();
    } finally {
      await celular.cerrar();
    }
  });

  tearDown(() => red()
    ..restablecer()
    ..registro.clear());

  const cantidad = 7;

  /// Aplique+color nuevo (sin stock) y el formulario con una línea de
  /// [cantidad], elegida con lo que carga la pantalla.
  Future<(ApliqueEnSucursal, ProduccionFormCubit)> listadoListo() async {
    final p = await datos.apliqueEnSucursalNueva();
    final cubit = ProduccionFormCubit(
      apliquesRepository: ApliquesRepositoryImpl(ApliquesDatasourceImpl()),
      idsucursal: p.sucursal,
    );
    addTearDown(cubit.close);
    // El constructor ya lanzó load() (apliques y stock de la sucursal)
    await cubit.stream.firstWhere((s) => !s.isLoading);
    await cubit.onApliqueChanged(
        cubit.state.apliques.singleWhere((a) => a.id == p.aplique));
    cubit
      ..onColorChanged(cubit.state.colores.single)
      ..onCantidadChanged('$cantidad')
      ..onFechaChanged(fechaRD);
    expect(cubit.addDetalleProduccion(), isNull);
    red().registro.clear();
    return (p, cubit);
  }

  /// Lo que quedó en la base, en una sola comparación (si falla, el mensaje
  /// muestra todo lo que quedó).
  Future<void> verificarFabricadoUnaVez(ApliqueEnSucursal p) async {
    final db = celular.base;
    final producciones = await produccionesDelDia(db, p.sucursal, fechaRD);
    final lineas = [
      for (final c in producciones)
        ...await lineasProduccion(db, c['id'] as int),
    ];
    expect({
      'stock': await stockDe(db, p),
      'producciones del día': producciones.length,
      'líneas': lineas.length,
      'cantidad de la línea':
          lineas.fold<double>(0, (suma, l) => suma + numero(l['cantidad'])),
    }, {
      'stock': cantidad,
      'producciones del día': 1,
      'líneas': 1,
      'cantidad de la línea': cantidad,
    }, reason: 'el stock sube y la línea suma una sola vez');
  }

  test(
      'respuesta perdida: la app muestra el error y conserva el listado, pero '
      'la producción ya quedó registrada en la base', () async {
    final (p, cubit) = await listadoListo();
    red().perderRespuesta(cuando: Cuando.rpc('registrar_produccion'));

    expect(await cubit.onFormSubmit(), isNotNull);

    expect(red().perdidas, ['rpc/registrar_produccion']);
    expect(cubit.state.detProducciones, hasLength(1),
        reason: 'el listado queda para volver a tocar Guardar');
    await verificarFabricadoUnaVez(p);
  });

  test(
      'respuesta perdida y el usuario vuelve a tocar Guardar: el stock sube '
      'una sola vez y la línea queda con la cantidad una vez', () async {
    final (p, cubit) = await listadoListo();
    red().perderRespuesta(cuando: Cuando.rpc('registrar_produccion'));
    expect(await cubit.onFormSubmit(), isNotNull);

    expect(await cubit.onFormSubmit(), isNull);

    // El reintento lleva la misma clave de operación: la base devuelve la
    // producción de la primera vez sin sumar nada
    expect(red().llegaron.where((r) => r == 'rpc/registrar_produccion'),
        hasLength(2));
    expect(cubit.state.detProducciones, isEmpty);
    await verificarFabricadoUnaVez(p);
  });

  test(
      'se corta la señal justo después del registro (falla el refresco del '
      'stock): la producción no se registra dos veces', () async {
    final (p, cubit) = await listadoListo();
    // El RPC llega y responde; todo lo que sigue (los GET de getStock, con
    // sus 3 reintentos automáticos de postgrest) no sale.
    red().cortar(cuando: Cuando.desdeLlamada(2));

    final error = await cubit.onFormSubmit();
    expect(red().entregadas, ['rpc/registrar_produccion']);
    red().restablecer();

    // El registro salió bien: no es un error aunque el stock no se haya
    // podido refrescar, y el listado ya no está para volver a mandarlo
    expect(error, isNull);
    expect(cubit.state.detProducciones, isEmpty);
    expect(cubit.state.isSubmitting, isFalse);
    // Si igual quedara el listado, el usuario volvería a tocar Guardar
    if (cubit.state.detProducciones.isNotEmpty) await cubit.onFormSubmit();
    await verificarFabricadoUnaVez(p);
  });

  test(
      'sin conexión: falla limpia (no llega nada a la base), conserva el '
      'listado y el reintento con señal fabrica una vez', () async {
    final (p, cubit) = await listadoListo();
    red().cortar();

    expect(await cubit.onFormSubmit(), isNotNull);

    expect(red().llegaron, isEmpty);
    expect(cubit.state.detProducciones, hasLength(1));
    expect(await stockDe(celular.base, p), 0);
    expect(
        await produccionesDelDia(celular.base, p.sucursal, fechaRD), isEmpty);

    red().restablecer();
    expect(await cubit.onFormSubmit(), isNull);
    expect(cubit.state.detProducciones, isEmpty);
    await verificarFabricadoUnaVez(p);
  });
}
