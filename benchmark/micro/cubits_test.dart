// Micro-benchmarks de los cubits: carritos (venta de telas, venta de
// apliques, fabricación), formularios, vinculación de telas/colores y
// dashboard. Todo contra fakes en memoria (test/helpers/).
//
//   flutter test benchmark/micro/cubits_test.dart
//
// Los carritos se miden sobre un cubit reseteado en cada iteración (subclase
// con `vaciar`) para que todas hagan el mismo trabajo.
@Tags(['benchmark'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/auth/auth.dart';
import 'package:textiles_app/features/colores/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';
import 'package:textiles_app/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/bloc.dart';

import '../../test/helpers/fake_repositories.dart';
import 'medicion.dart';

final _fecha = DateTime(2026, 10, 11);

/// Evita que el compilador descarte lecturas cuyo resultado no se usa.
var _sumidero = 0;

// ---------------------------------------------------------------------------
// Fakes que no acumulan llamadas: el benchmark las repite miles de veces y
// las listas de registro de los fakes compartidos crecerían sin límite.
// ---------------------------------------------------------------------------

final _ventaDelDia = Venta(
  id: 1,
  fecha: _fecha,
  total: 0,
  ganancias: 0,
  descuento: 0,
  idsucursales: 1,
);

class _VentasRepo extends FakeVentasRepository {
  _VentasRepo() {
    ventaByFecha = _ventaDelDia;
  }

  @override
  Future<Venta> actualizarVenta(Map<String, dynamic> ventaLike, int id) async =>
      _ventaDelDia;
}

class _DetalleVentasRepo extends FakeDetalleVentasRepository {
  @override
  Future<List<DetalleVenta>> createDetalleVenta(
          List<Map<String, dynamic>> detalleVentasLike, int idventas) async =>
      const [];
}

class _VentasApliquesRepo extends FakeVentasApliquesRepository {
  @override
  Future<int> createVentaAplique({
    required int idsucursales,
    required double total,
    required double ganancias,
    required double descuento,
    required List<Map<String, dynamic>> detalles,
  }) async =>
      1;
}

class _ApliquesRepo extends FakeApliquesRepository {
  _ApliquesRepo({super.apliques, super.stock, super.colores});

  @override
  Future<void> createProduccion({
    required int sucursalId,
    required DateTime fecha,
    required List<Map<String, dynamic>> lineas,
  }) async {}

  @override
  Future<void> setColorAplique(int idaplique, int idcolor, bool activo) async {}
}

class _TelasRepo extends FakeTelasRepository {
  _TelasRepo({super.telas, super.colores});

  @override
  Future<void> setColorTela(int idtela, int idcolor, bool activo) async {}
}

class _SucursalesRepo extends FakeSucursalesRepository {
  _SucursalesRepo({super.telasSucursal});

  @override
  Future<void> setTelaSucursal(int idtela, int idsucursal, bool activo) async {}
}

class _DashboardRepo extends FakeDashboardRepository {
  _DashboardRepo({super.topTelas, super.topApliques});

  @override
  Future<List<TopProducto>> getTopProductos(
          {required DateTime desde, required DateTime hasta}) async =>
      topTelas;

  @override
  Future<List<TopProducto>> getTopApliques(
          {required DateTime desde, required DateTime hasta}) async =>
      topApliques;

  @override
  Future<ResumenVentas> getResumenVentas(
          {required DateTime desde, required DateTime hasta}) async =>
      resumenTelas;

  @override
  Future<ResumenVentas> getResumenVentasApliques(
          {required DateTime desde, required DateTime hasta}) async =>
      resumenApliques;
}

// ---------------------------------------------------------------------------
// Cubits con `vaciar`: vuelven al estado inicial sin crear otro cubit.
// ---------------------------------------------------------------------------

class _CarritoTelas extends DetalleVentaFormCubit {
  _CarritoTelas()
      : super(
          ventasRepository: _VentasRepo(),
          detalleVentasRepository: _DetalleVentasRepo(),
          idsucursal: 1,
        );

  void vaciar() => emit(DetalleVentaFormState(fecha: _fecha));
}

class _CarritoApliques extends VentaApliquesFormCubit {
  _CarritoApliques()
      : super(ventasApliquesRepository: _VentasApliquesRepo(), idsucursal: 1);

  void vaciar() => emit(VentaApliquesFormState());
}

class _Fabricacion extends ProduccionFormCubit {
  _Fabricacion(ApliquesRepository repo)
      : super(apliquesRepository: repo, idsucursal: 1);

  void vaciar() => emit(state.copyWith(detProducciones: const []));

  void cargarLineas(List<Map<String, dynamic>> lineas) =>
      emit(state.copyWith(detProducciones: lineas));
}

// ---------------------------------------------------------------------------
// Datos
// ---------------------------------------------------------------------------

List<Tela> _telas(int n) => [
      for (var i = 1; i <= n; i++)
        Tela(
          id: i,
          nombre: 'Tela $i',
          precxmen: 12.5,
          precxmay: 10,
          precxrollo: 350,
          precxcompra: 6,
          activo: i % 10 != 0,
        ),
    ];

/// 40 apliques x 5 colores alcanzan para 200 líneas distintas.
final _apliques = [
  for (var i = 1; i <= 40; i++)
    Aplique(
      id: i,
      nombre: 'Flor $i - Bolsa x100 und',
      costoFabricacion: 2.5,
      anchoCm: 4,
      altoCm: 4,
    ),
];

final _coloresVinculados = [
  for (var c = 1; c <= 5; c++)
    ColorItem(id: c, nombre: 'Color $c', hex: 'A0B0C$c', vinculado: true),
];

StockAplique _stock(int apliqueId, int colorId, double stock) => StockAplique(
      apliqueId: apliqueId,
      colorId: colorId,
      colorNombre: 'Color $colorId',
      hex: 'A0B0C$colorId',
      stock: stock,
    );

/// Nombres desordenados y con mayúsculas mezcladas (el cubit los ordena).
List<ColorItem> _colores(int n) => [
      for (var i = 0; i < n; i++)
        ColorItem(
          id: i + 1,
          nombre: '${i.isEven ? 'Rojo' : 'azul'} ${(i * 7919) % n}',
          hex: 'FF${(i % 100).toString().padLeft(2, '0')}00',
          vinculado: i % 3 == 0,
        ),
    ];

List<TelaSucursal> _telasSucursal(int n) => [
      for (var i = 1; i <= n; i++)
        TelaSucursal(idtela: i, nombre: 'Tela $i', disponible: i.isEven),
    ];

/// Como las RPC: ordenado por monto; la cantidad queda desordenada.
List<TopProducto> _ranking(int n, String prefijo) => [
      for (var i = 0; i < n; i++)
        TopProducto(
          nombre: '$prefijo ${i + 1}',
          totalVendido: (n - i) * 100.0,
          totalCantidad: ((i * 37) % n) + 1.5,
        ),
    ];

/// Cada tecla de [texto]: 'G', 'Ga', 'Gab', ...
List<String> _teclas(String texto) =>
    [for (var i = 1; i <= texto.length; i++) texto.substring(0, i)];

// ---------------------------------------------------------------------------
// Flujos de la UI
// ---------------------------------------------------------------------------

/// Como DetVenta: elegir tela, tipear precio y cantidad, Añadir.
void _agregarTela(DetalleVentaFormCubit cubit, Tela tela) {
  cubit.onPrecxCompraChanged(tela.precxcompra ?? 0);
  cubit.onNombreChanged(tela.nombre);
  cubit.onIdTelasChanged(tela.id);
  cubit.onPrecioChanged('12.5');
  cubit.onCantidadChanged('3');
  cubit.addDetalleVenta();
}

/// Como VentaApliquesScreen: elegir aplique y color, precio, cantidad, Añadir.
String? _agregarAplique(
  VentaApliquesFormCubit cubit,
  Aplique aplique,
  StockAplique color,
) {
  cubit.onApliqueChanged(aplique);
  cubit.onColorChanged(color);
  cubit.onPrecioChanged('8');
  cubit.onCantidadChanged('1');
  return cubit.addDetalle();
}

/// La línea i: aplique i ~/ 5, color i % 5 (todas distintas hasta 200).
List<(Aplique, StockAplique)> _lineasApliques(int n, {bool repetida = false}) =>
    [
      for (var i = 0; i < n; i++)
        repetida
            ? (_apliques.first, _stock(_apliques.first.id, 1, 100000))
            : (
                _apliques[i ~/ 5],
                _stock(_apliques[i ~/ 5].id, i % 5 + 1, 100000),
              ),
    ];

/// Como ProduccionScreen: el aplique se elige una vez por cada 5 colores.
Future<void> _fabricar(_Fabricacion cubit, int n,
    {bool repetida = false}) async {
  for (var i = 0; i < n; i++) {
    if (repetida) {
      if (i == 0) await cubit.onApliqueChanged(_apliques.first);
      cubit.onColorChanged(_coloresVinculados.first);
    } else {
      if (i % 5 == 0) await cubit.onApliqueChanged(_apliques[i ~/ 5]);
      cubit.onColorChanged(_coloresVinculados[i % 5]);
    }
    cubit.onCantidadChanged('4');
    cubit.addDetalleProduccion();
  }
}

Future<_Fabricacion> _crearFabricacion() async {
  final cubit = _Fabricacion(_ApliquesRepo(
    apliques: _apliques,
    stock: [for (final a in _apliques) _stock(a.id, 1, 10)],
    colores: _coloresVinculados,
  ));
  addTearDown(cubit.close);
  // El constructor dispara load(): esperar a que termine antes de medir.
  await cubit.stream.firstWhere((s) => !s.isLoading);
  return cubit;
}

/// [microBenchmark] con el presupuesto de [_presupuestos].
void _micro(
  String nombre,
  void Function() operacion, {
  void Function()? preparar,
}) =>
    microBenchmark(
      nombre,
      operacion,
      presupuestoUs: _presupuesto(nombre),
      preparar: preparar,
    );

/// [microBenchmarkAsync] con el presupuesto de [_presupuestos].
void _microAsync(
  String nombre,
  Future<void> Function() operacion, {
  Future<void> Function()? preparar,
}) =>
    microBenchmarkAsync(
      nombre,
      operacion,
      presupuestoUs: _presupuesto(nombre),
      preparar: preparar,
    );

double _presupuesto(String nombre) =>
    _presupuestos[nombre] ??
    (throw ArgumentError('Falta el presupuesto de "$nombre"'));

void main() {
  grupoBenchmark('cubits', () {
    // ---------------------------------------------------------------- telas
    group('DetalleVentaFormCubit', () {
      for (final n in [10, 50, 200]) {
        final telas = _telas(n);
        late _CarritoTelas cubit;
        void llenar() {
          cubit.vaciar();
          for (final t in telas) {
            _agregarTela(cubit, t);
          }
        }

        _micro(
          'DetalleVentaFormCubit agregar x$n (telas distintas)',
          llenar,
          preparar: () {
            cubit = _CarritoTelas();
            addTearDown(cubit.close);
            llenar();
            expect(cubit.state.detVentas, hasLength(n));
          },
        );
      }

      {
        final tela = _telas(1).first;
        late _CarritoTelas cubit;
        void llenar() {
          cubit.vaciar();
          for (var i = 0; i < 200; i++) {
            _agregarTela(cubit, tela);
          }
        }

        _micro(
          'DetalleVentaFormCubit agregar x200 (mismo precio suma)',
          llenar,
          preparar: () {
            cubit = _CarritoTelas();
            addTearDown(cubit.close);
            llenar();
            expect(cubit.state.detVentas, hasLength(1));
            expect(cubit.state.detVentas.first['cantidad'], 600);
          },
        );
      }

      {
        // Quita la línea más vieja (la última: peor caso del indexWhere) y la
        // vuelve a agregar adelante; el carrito rota y siempre tiene 200.
        final telas = _telas(200);
        late _CarritoTelas cubit;
        var k = 0;
        _micro(
          'DetalleVentaFormCubit quitar y reagregar 1 línea (carrito de 200)',
          () {
            final tela = telas[k++ % 200];
            cubit.removeDetalleVenta(tela.id, 3, 12.5);
            _agregarTela(cubit, tela);
          },
          preparar: () {
            cubit = _CarritoTelas();
            addTearDown(cubit.close);
            for (final t in telas) {
              _agregarTela(cubit, t);
            }
            expect(cubit.state.detVentas.last['idtelas'], 1);
          },
        );
      }

      {
        late _CarritoTelas cubit;
        _microAsync(
          'DetalleVentaFormCubit onFormSubmit (carrito de 200, venta del día)',
          () async {
            await cubit.onFormSubmit();
          },
          preparar: () async {
            cubit = _CarritoTelas();
            addTearDown(cubit.close);
            for (final t in _telas(200)) {
              _agregarTela(cubit, t);
            }
            expect(await cubit.onFormSubmit(), isTrue);
          },
        );
      }
    });

    // ------------------------------------------------------------- apliques
    group('VentaApliquesFormCubit', () {
      for (final n in [10, 50, 200]) {
        final lineas = _lineasApliques(n);
        late _CarritoApliques cubit;
        void llenar() {
          cubit.vaciar();
          for (final (aplique, color) in lineas) {
            _agregarAplique(cubit, aplique, color);
          }
        }

        _micro(
          'VentaApliquesFormCubit agregar x$n (aplique+color distintos)',
          llenar,
          preparar: () {
            cubit = _CarritoApliques();
            addTearDown(cubit.close);
            llenar();
            expect(cubit.state.detalles, hasLength(n));
          },
        );
      }

      {
        final lineas = _lineasApliques(200, repetida: true);
        late _CarritoApliques cubit;
        void llenar() {
          cubit.vaciar();
          for (final (aplique, color) in lineas) {
            _agregarAplique(cubit, aplique, color);
          }
        }

        _micro(
          'VentaApliquesFormCubit agregar x200 (mismo aplique+color+precio suma)',
          llenar,
          preparar: () {
            cubit = _CarritoApliques();
            addTearDown(cubit.close);
            llenar();
            expect(cubit.state.detalles, hasLength(1));
            expect(cubit.state.detalles.first['cantidad'], 200);
          },
        );
      }

      {
        // El aplique+color ya está en el carrito y pedir 5 más supera el
        // stock: addDetalle recorre las 200 líneas y devuelve el error.
        late _CarritoApliques cubit;
        _micro(
          'VentaApliquesFormCubit rechazo por sobre-stock (carrito de 200)',
          () => _sumidero += cubit.addDetalle()!.length,
          preparar: () {
            cubit = _CarritoApliques();
            addTearDown(cubit.close);
            for (final (aplique, color) in _lineasApliques(200)) {
              _agregarAplique(cubit, aplique, color);
            }
            cubit.onApliqueChanged(_apliques.first);
            cubit.onColorChanged(_stock(_apliques.first.id, 1, 3));
            cubit.onPrecioChanged('8');
            cubit.onCantidadChanged('5');
            expect(cubit.addDetalle(), startsWith('Stock insuficiente'));
            expect(cubit.state.detalles, hasLength(200));
          },
        );
      }

      {
        late _CarritoApliques cubit;
        _microAsync(
          'VentaApliquesFormCubit onFormSubmit (carrito de 200)',
          () async {
            await cubit.onFormSubmit();
          },
          preparar: () async {
            cubit = _CarritoApliques();
            addTearDown(cubit.close);
            for (final (aplique, color) in _lineasApliques(200)) {
              _agregarAplique(cubit, aplique, color);
            }
            expect(await cubit.onFormSubmit(), isTrue);
          },
        );
      }
    });

    // ----------------------------------------------------------- fabricación
    group('ProduccionFormCubit', () {
      for (final n in [10, 50, 200]) {
        late _Fabricacion cubit;
        _microAsync(
          'ProduccionFormCubit agregar x$n (elige aplique y color por línea)',
          () async {
            cubit.vaciar();
            await _fabricar(cubit, n);
          },
          preparar: () async {
            cubit = await _crearFabricacion();
            await _fabricar(cubit, n);
            expect(cubit.state.detProducciones, hasLength(n));
          },
        );
      }

      {
        late _Fabricacion cubit;
        _microAsync(
          'ProduccionFormCubit agregar x200 (mismo aplique+color suma)',
          () async {
            cubit.vaciar();
            await _fabricar(cubit, 200, repetida: true);
          },
          preparar: () async {
            cubit = await _crearFabricacion();
            await _fabricar(cubit, 200, repetida: true);
            expect(cubit.state.detProducciones, hasLength(1));
            expect(cubit.state.detProducciones.first['cantidad'], 800);
          },
        );
      }

      {
        // onFormSubmit vacía el listado: se repone (un emit) en cada vuelta.
        late _Fabricacion cubit;
        late List<Map<String, dynamic>> lineas;
        _microAsync(
          'ProduccionFormCubit onFormSubmit (200 líneas + refresco de stock)',
          () async {
            cubit.cargarLineas(lineas);
            await cubit.onFormSubmit();
          },
          preparar: () async {
            cubit = await _crearFabricacion();
            await _fabricar(cubit, 200);
            lineas = cubit.state.detProducciones;
            expect(await cubit.onFormSubmit(), isNull);
            expect(cubit.state.detProducciones, isEmpty);
          },
        );
      }
    });

    // ----------------------------------------------------------- formularios
    group('formularios', () {
      Future<bool> ok(Map<String, dynamic> _) async => true;

      {
        final nombre = _teclas('Gabardina Stretch Premium');
        final precios = _teclas('12.50');
        late TelaFormCubit cubit;
        _micro(
          'TelaFormCubit tipear nombre + 4 precios (45 teclas)',
          () {
            for (final t in nombre) {
              cubit.onNombreChanged(t);
            }
            for (final t in precios) {
              cubit.onPrecxmenChanged(t);
              cubit.onPrecxmayChanged(t);
              cubit.onPrecxrolloChanged(t);
              cubit.onPrecxcompraChanged(t);
            }
          },
          preparar: () {
            cubit = TelaFormCubit(
              onCreateCallback: ok,
              onUpdateCallback: ok,
              tela: Tela(id: 0, nombre: ''),
            );
            addTearDown(cubit.close);
          },
        );
      }

      for (final (caso, precio, esperado) in [
        ('válido', '12.50', true),
        ('inválido', '12,50', false),
      ]) {
        late TelaFormCubit cubit;
        _microAsync(
          'TelaFormCubit onSubmit $caso',
          () async {
            await cubit.onSubmit(isUpdate: true);
          },
          preparar: () async {
            cubit = TelaFormCubit(
              onCreateCallback: ok,
              onUpdateCallback: ok,
              tela: Tela(id: 3, nombre: ''),
            );
            addTearDown(cubit.close);
            cubit
              ..onNombreChanged('Gabardina')
              ..onPrecxmenChanged(precio)
              ..onPrecxmayChanged('10')
              ..onPrecxrolloChanged('350')
              ..onPrecxcompraChanged('6.8');
            expect(await cubit.onSubmit(isUpdate: true), esperado);
          },
        );
      }

      {
        final nombre = _teclas('Flor Petalo Suizo Grande - Bolsa x100 und');
        final medida = _teclas('4.5');
        late ApliqueFormCubit cubit;
        _micro(
          'ApliqueFormCubit tipear nombre + medidas + costo (50 teclas)',
          () {
            for (final t in nombre) {
              cubit.onNombreChanged(t);
            }
            for (final t in medida) {
              cubit.onAnchoChanged(t);
              cubit.onAltoChanged(t);
              cubit.onCostoChanged(t);
            }
          },
          preparar: () {
            cubit = ApliqueFormCubit(
              onCreateCallback: ok,
              onUpdateCallback: ok,
              aplique: Aplique(id: 0, nombre: ''),
            );
            addTearDown(cubit.close);
          },
        );
      }

      {
        late ApliqueFormCubit cubit;
        _microAsync(
          'ApliqueFormCubit onSubmit válido',
          () async {
            await cubit.onSubmit(isUpdate: true);
          },
          preparar: () async {
            cubit = ApliqueFormCubit(
              onCreateCallback: ok,
              onUpdateCallback: ok,
              aplique: _apliques.first,
            );
            addTearDown(cubit.close);
            expect(await cubit.onSubmit(isUpdate: true), isTrue);
          },
        );
      }

      {
        final nombre = _teclas('Sucursal Mercado Mutualista');
        late SucursalFormCubit cubit;
        _micro(
          'SucursalFormCubit tipear nombre (27 teclas)',
          () {
            for (final t in nombre) {
              cubit.onNombreChanged(t);
            }
          },
          preparar: () {
            cubit = SucursalFormCubit(
              onCreateCallback: ok,
              onUpdateCallback: ok,
              onDeleteCallback: (_) async => true,
              sucursal: Sucursal(id: 0, nombre: ''),
            );
            addTearDown(cubit.close);
          },
        );
      }

      {
        late SucursalFormCubit cubit;
        _microAsync(
          'SucursalFormCubit onSubmit válido',
          () async {
            await cubit.onSubmit(isUpdate: true);
          },
          preparar: () async {
            cubit = SucursalFormCubit(
              onCreateCallback: ok,
              onUpdateCallback: ok,
              onDeleteCallback: (_) async => true,
              sucursal: Sucursal(id: 2, nombre: '  Mutualista  '),
            );
            addTearDown(cubit.close);
            expect(await cubit.onSubmit(isUpdate: true), isTrue);
          },
        );
      }

      {
        final nombre = _teclas('Azul Marino Oscuro');
        final hex = _teclas('#1a2b3c');
        late ColorFormCubit cubit;
        _micro(
          'ColorFormCubit tipear nombre + hex (25 teclas)',
          () {
            for (final t in nombre) {
              cubit.onNombreChanged(t);
            }
            for (final t in hex) {
              cubit.onHexChanged(t);
            }
          },
          preparar: () {
            cubit = ColorFormCubit(
              onCreateCallback: ok,
              onUpdateCallback: ok,
              onDeleteCallback: (_) async => true,
              color: const ColorItem(id: 0, nombre: ''),
            );
            addTearDown(cubit.close);
          },
        );
      }

      {
        late ColorFormCubit cubit;
        _microAsync(
          'ColorFormCubit onSubmit válido (normaliza el hex)',
          () async {
            await cubit.onSubmit(isUpdate: true);
          },
          preparar: () async {
            cubit = ColorFormCubit(
              onCreateCallback: ok,
              onUpdateCallback: ok,
              onDeleteCallback: (_) async => true,
              color: const ColorItem(id: 4, nombre: 'Azul', hex: '#1a2b3c'),
            );
            addTearDown(cubit.close);
            expect(await cubit.onSubmit(isUpdate: true), isTrue);
          },
        );
      }

      {
        final email = _teclas(FakeAuthRepository.emailOk);
        final password = _teclas(FakeAuthRepository.passwordOk);
        late LoginFormCubit cubit;
        _micro(
          'LoginFormCubit tipear email + contraseña (24 teclas)',
          () {
            for (final t in email) {
              cubit.onEmailChanged(t);
            }
            for (final t in password) {
              cubit.onPasswordChanged(t);
            }
          },
          preparar: () {
            cubit = LoginFormCubit(authRepository: FakeAuthRepository());
            addTearDown(cubit.close);
          },
        );
      }

      for (final (caso, password, esperado) in [
        ('correcto', FakeAuthRepository.passwordOk, true),
        ('contraseña incorrecta', 'otra', false),
      ]) {
        late LoginFormCubit cubit;
        _microAsync(
          'LoginFormCubit onSubmit $caso',
          () async {
            await cubit.onSubmit();
          },
          preparar: () async {
            cubit = LoginFormCubit(authRepository: FakeAuthRepository());
            addTearDown(cubit.close);
            cubit
              ..onEmailChanged(FakeAuthRepository.emailOk)
              ..onPasswordChanged(password);
            expect(await cubit.onSubmit(), esperado);
          },
        );
      }
    });

    // ------------------------------------------------- vinculación y colores
    group('SucursalDisponibilidadCubit', () {
      for (final n in [10, 100, 500]) {
        late SucursalDisponibilidadCubit cubit;
        Future<void> crear() async {
          cubit = SucursalDisponibilidadCubit(
            sucursalesRepository: _SucursalesRepo(
              telasSucursal: _telasSucursal(n),
            ),
            idsucursal: 1,
          );
          addTearDown(cubit.close);
          await cubit.stream.firstWhere((s) => !s.isLoading);
          expect(cubit.state.telas, hasLength(n));
        }

        _microAsync(
          'SucursalDisponibilidadCubit cargar $n telas',
          () => cubit.load(),
          preparar: crear,
        );

        var disponible = false;
        _microAsync(
          'SucursalDisponibilidadCubit vincular/desvincular 1 tela (de $n)',
          () {
            disponible = !disponible;
            return cubit.toggleTela(n ~/ 2, disponible);
          },
          preparar: crear,
        );
      }
    });

    group('TelaColoresCubit', () {
      for (final n in [10, 100, 500]) {
        late TelaColoresCubit cubit;
        Future<void> crear() async {
          cubit = TelaColoresCubit(
            telasRepository: _TelasRepo(telas: _telas(1), colores: _colores(n)),
            idtela: 1,
          );
          addTearDown(cubit.close);
          await cubit.stream.firstWhere((s) => !s.isLoading);
          expect(cubit.state.colores, hasLength(n));
        }

        _microAsync(
          'TelaColoresCubit cargar $n colores',
          () => cubit.load(),
          preparar: crear,
        );

        var vinculado = false;
        _microAsync(
          'TelaColoresCubit vincular/desvincular 1 color (de $n)',
          () {
            vinculado = !vinculado;
            return cubit.toggleColor(n ~/ 2, vinculado);
          },
          preparar: crear,
        );
      }
    });

    group('ApliqueColoresCubit', () {
      for (final n in [10, 100, 500]) {
        late ApliqueColoresCubit cubit;
        Future<void> crear() async {
          cubit = ApliqueColoresCubit(
            apliquesRepository:
                _ApliquesRepo(apliques: _apliques, colores: _colores(n)),
            idaplique: _apliques.last.id,
          );
          addTearDown(cubit.close);
          await cubit.stream.firstWhere((s) => !s.isLoading);
          expect(cubit.state.colores, hasLength(n));
          expect(cubit.state.nombreAplique, _apliques.last.nombre);
        }

        _microAsync(
          'ApliqueColoresCubit cargar $n colores (ordena por nombre)',
          () => cubit.load(),
          preparar: crear,
        );

        var vinculado = false;
        _microAsync(
          'ApliqueColoresCubit vincular/desvincular 1 color (de $n)',
          () {
            vinculado = !vinculado;
            return cubit.toggleColor(n ~/ 2, vinculado);
          },
          preparar: crear,
        );
      }
    });

    // ------------------------------------------------------------- dashboard
    group('DashboardCubit', () {
      for (final n in [10, 100, 500]) {
        late DashboardCubit cubit;
        _microAsync(
          'DashboardCubit cargar 4 RPC (rankings de $n)',
          () => cubit.cargar(),
          preparar: () async {
            cubit = DashboardCubit(
              repository: _DashboardRepo(
                topTelas: _ranking(n, 'Tela'),
                topApliques: _ranking(n, 'Aplique'),
              ),
            );
            addTearDown(cubit.close);
            await cubit.stream.firstWhere((s) => !s.isLoading);
            expect(cubit.state.topTelas, hasLength(n));
          },
        );
      }

      // telasOrdenadas/apliquesOrdenados son getters: copian y ordenan en
      // cada lectura, y DashboardScreen los lee en cada build.
      for (final n in [10, 100, 500]) {
        late DashboardState estado;
        _micro(
          'DashboardState leer rankings por cantidad (2 x $n, ordena)',
          () => _sumidero +=
              estado.telasOrdenadas.length + estado.apliquesOrdenados.length,
          preparar: () {
            estado = DashboardState(
              topTelas: _ranking(n, 'Tela'),
              topApliques: _ranking(n, 'Aplique'),
              verPorCantidad: true,
              desde: _fecha,
              hasta: _fecha,
            );
            expect(estado.telasOrdenadas.first.totalCantidad,
                greaterThanOrEqualTo(estado.telasOrdenadas.last.totalCantidad));
          },
        );
      }
    });
  });
}

/// Presupuestos (µs/op): ~10x el peor valor de 3 corridas seguidas de
/// `flutter test benchmark/micro` (JIT, Windows, 2026-10-11), redondeado hacia
/// arriba a 2 cifras. Al agregar un benchmark, agregar su fila (si falta, el
/// archivo no carga); al cambiar de máquina de referencia, recalibrar.
const _presupuestos = <String, double>{
  'DetalleVentaFormCubit agregar x10 (telas distintas)': 170,
  'DetalleVentaFormCubit agregar x50 (telas distintas)': 1200,
  'DetalleVentaFormCubit agregar x200 (telas distintas)': 8500,
  'DetalleVentaFormCubit agregar x200 (mismo precio suma)': 2000,
  'DetalleVentaFormCubit quitar y reagregar 1 línea (carrito de 200)': 160,
  'DetalleVentaFormCubit onFormSubmit (carrito de 200, venta del día)': 430,
  'VentaApliquesFormCubit agregar x10 (aplique+color distintos)': 160,
  'VentaApliquesFormCubit agregar x50 (aplique+color distintos)': 1900,
  'VentaApliquesFormCubit agregar x200 (aplique+color distintos)': 31000,
  'VentaApliquesFormCubit agregar x200 (mismo aplique+color+precio suma)': 3000,
  'VentaApliquesFormCubit rechazo por sobre-stock (carrito de 200)': 130,
  'VentaApliquesFormCubit onFormSubmit (carrito de 200)': 930,
  'ProduccionFormCubit agregar x10 (elige aplique y color por línea)': 770,
  'ProduccionFormCubit agregar x50 (elige aplique y color por línea)': 3600,
  'ProduccionFormCubit agregar x200 (elige aplique y color por línea)': 20000,
  'ProduccionFormCubit agregar x200 (mismo aplique+color suma)': 1900,
  'ProduccionFormCubit onFormSubmit (200 líneas + refresco de stock)': 990,
  'TelaFormCubit tipear nombre + 4 precios (45 teclas)': 24,
  'TelaFormCubit onSubmit válido': 290,
  'TelaFormCubit onSubmit inválido': 220,
  'ApliqueFormCubit tipear nombre + medidas + costo (50 teclas)': 32,
  'ApliqueFormCubit onSubmit válido': 290,
  'SucursalFormCubit tipear nombre (27 teclas)': 13,
  'SucursalFormCubit onSubmit válido': 240,
  'ColorFormCubit tipear nombre + hex (25 teclas)': 13,
  'ColorFormCubit onSubmit válido (normaliza el hex)': 440,
  'LoginFormCubit tipear email + contraseña (24 teclas)': 15,
  'LoginFormCubit onSubmit correcto': 540,
  'LoginFormCubit onSubmit contraseña incorrecta': 600,
  'SucursalDisponibilidadCubit cargar 10 telas': 430,
  'SucursalDisponibilidadCubit vincular/desvincular 1 tela (de 10)': 320,
  'SucursalDisponibilidadCubit cargar 100 telas': 560,
  'SucursalDisponibilidadCubit vincular/desvincular 1 tela (de 100)': 800,
  'SucursalDisponibilidadCubit cargar 500 telas': 790,
  'SucursalDisponibilidadCubit vincular/desvincular 1 tela (de 500)': 540,
  'TelaColoresCubit cargar 10 colores': 350,
  'TelaColoresCubit vincular/desvincular 1 color (de 10)': 330,
  'TelaColoresCubit cargar 100 colores': 440,
  'TelaColoresCubit vincular/desvincular 1 color (de 100)': 280,
  'TelaColoresCubit cargar 500 colores': 670,
  'TelaColoresCubit vincular/desvincular 1 color (de 500)': 470,
  'ApliqueColoresCubit cargar 10 colores (ordena por nombre)': 280,
  'ApliqueColoresCubit vincular/desvincular 1 color (de 10)': 390,
  'ApliqueColoresCubit cargar 100 colores (ordena por nombre)': 1400,
  'ApliqueColoresCubit vincular/desvincular 1 color (de 100)': 360,
  'ApliqueColoresCubit cargar 500 colores (ordena por nombre)': 5700,
  'ApliqueColoresCubit vincular/desvincular 1 color (de 500)': 1300,
  'DashboardCubit cargar 4 RPC (rankings de 10)': 6300,
  'DashboardCubit cargar 4 RPC (rankings de 100)': 1800,
  'DashboardCubit cargar 4 RPC (rankings de 500)': 770,
  'DashboardState leer rankings por cantidad (2 x 10, ordena)': 16,
  'DashboardState leer rankings por cantidad (2 x 100, ordena)': 510,
  'DashboardState leer rankings por cantidad (2 x 500, ordena)': 3900,
};
