import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/inventario_cubit.dart';

import '../../../../helpers/fake_repositories.dart';

StockConVentas _item(String color,
        {double stock = 0, double vendidas = 0, double vendidasOtras = 0}) =>
    StockConVentas(
      apliqueId: 1,
      aplique: 'Flor',
      colorId: color.hashCode,
      color: color,
      hex: '',
      stock: stock,
      vendidas: vendidas,
      vendidasOtras: vendidasOtras,
    );

void main() {
  final hoy = DateTime(2026, 10, 15, 18, 30);

  // Rojo falta (mínimo 5, quedan 2 → 8), Azul sobra, Verde no se vende
  final inventario = [
    _item('Azul', stock: 50, vendidas: 8),
    _item('Rojo', stock: 2, vendidas: 8),
    _item('Verde', stock: 0),
  ];

  late FakeApliquesRepository repo;

  setUp(() {
    repo = FakeApliquesRepository(inventarioConVentas: inventario);
  });

  Future<InventarioCubit> crear() async {
    final cubit = InventarioCubit(
        apliquesRepository: repo, idsucursal: 2, hoy: () => hoy);
    addTearDown(cubit.close);
    await cubit.stream.firstWhere((s) => !s.isLoading);
    return cubit;
  }

  // El estado inicial del cubit: hasta que llega la primera carga, la
  // pantalla no tiene que mostrar ni el error ni que está cargando de más
  test('un InventarioState nuevo no carga, no marca error y muestra faltantes',
      () {
    final estado = InventarioState(fecha: DateTime(2026, 10, 15));

    expect(estado.isLoading, isFalse);
    expect(estado.error, isFalse);
    expect(estado.items, isEmpty);
    expect(estado.soloFaltantes, isTrue);
  });

  test('copyWith cambia la fecha (va en el mensaje al fabricante)', () {
    final estado = InventarioState(fecha: DateTime(2026, 10, 15));

    expect(estado.copyWith(fecha: DateTime(2026, 10, 20)).fecha,
        DateTime(2026, 10, 20));
    expect(estado.copyWith().fecha, DateTime(2026, 10, 15));
  });

  test('recargar otro día usa la fecha y la ventana nuevas', () async {
    var ahora = DateTime(2026, 10, 15);
    final cubit = InventarioCubit(
        apliquesRepository: repo, idsucursal: 2, hoy: () => ahora);
    addTearDown(cubit.close);
    await cubit.stream.firstWhere((s) => !s.isLoading);

    ahora = DateTime(2026, 10, 20);
    await cubit.cargar();

    expect(cubit.state.fecha, DateTime(2026, 10, 20));
    final (_, desde, hasta) = repo.inventarioConVentasPedidos.last;
    expect(desde, DateTime(2026, 9, 23));
    expect(hasta, DateTime(2026, 10, 20));
  });

  test('al crearse carga las ventas de las últimas 4 semanas, hoy incluido',
      () async {
    await crear();

    final (sucursal, desde, hasta) = repo.inventarioConVentasPedidos.single;
    expect(sucursal, 2);
    expect(desde, DateTime(2026, 9, 18));
    expect(hasta, hoy);
    expect(hasta.difference(desde).inDays, 27,
        reason: '28 días contando los dos extremos');
  });

  test('aplica la regla: faltantes primero y el total a hacer', () async {
    final cubit = await crear();

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.error, isFalse);
    expect(cubit.state.items.map((r) => r.item.color),
        ['Rojo', 'Azul', 'Verde']);
    expect(cubit.state.faltantes.single.hacer, 8);
    expect(cubit.state.totalAHacer, 8);
    expect(cubit.state.fecha, hoy);
    expect(cubit.state.estimada, isFalse);
  });

  test('por defecto muestra solo los faltantes; el filtro va y vuelve',
      () async {
    final cubit = await crear();
    expect(cubit.state.soloFaltantes, isTrue);
    expect(cubit.state.visibles.map((r) => r.item.color), ['Rojo']);

    cubit.toggleSoloFaltantes();
    expect(cubit.state.visibles, hasLength(3));

    cubit.toggleSoloFaltantes();
    expect(cubit.state.visibles, hasLength(1));
  });

  test('una sucursal sin ventas propias queda estimada', () async {
    repo.inventarioConVentas = [
      _item('Rojo', vendidasOtras: 8),
      _item('Azul'),
    ];
    final cubit = await crear();

    expect(cubit.state.estimada, isTrue);
    expect(cubit.state.faltantes.single.item.color, 'Rojo');
  });

  test('sin inventario no está estimada ni falta nada', () async {
    repo.inventarioConVentas = const [];
    final cubit = await crear();

    expect(cubit.state.items, isEmpty);
    expect(cubit.state.estimada, isFalse);
    expect(cubit.state.totalAHacer, 0);
  });

  test('si falla la carga avisa el error (no "no falta nada") y reintenta',
      () async {
    repo.error = Exception('Sin conexión');
    final cubit = await crear();

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.error, isTrue);
    expect(cubit.state.items, isEmpty);

    repo.error = null;
    await cubit.cargar();

    expect(cubit.state.error, isFalse);
    expect(cubit.state.faltantes, hasLength(1));
  });

  test('recargar mantiene el filtro elegido', () async {
    final cubit = await crear();
    cubit.toggleSoloFaltantes();

    await cubit.cargar();

    expect(cubit.state.soloFaltantes, isFalse);
  });
}
