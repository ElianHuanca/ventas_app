import 'dart:async';

import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/auth/auth.dart';
import 'package:textiles_app/features/colores/domain/domain.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';
import 'package:textiles_app/features/fotos/domain/domain.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';

/// Fakes en memoria de los repositorios de domain.
/// Registran las llamadas recibidas para poder verificarlas en los tests
/// y permiten configurar respuestas y errores sin tocar Supabase.

class FakeVentasRepository implements VentasRepository {
  /// Respuesta configurable de getVentaByFecha (null = no existe venta).
  Venta? ventaByFecha;

  /// Respuesta de getVentas.
  List<Venta> ventas;

  /// Respuesta de getVenta (null = una venta en 0 con el id pedido).
  Venta? venta;

  FakeVentasRepository({this.ventas = const [], this.venta});

  int nextVentaId = 10;
  int createVentaCalls = 0;
  int createVentaAhoraCalls = 0;
  int getVentasCalls = 0;
  int? lastGetVentasSucursalId;
  final List<int> ventasEliminadas = [];
  List<Map<String, dynamic>> actualizaciones = [];
  List<int> idsActualizados = [];
  Exception? error;

  void _throwIfError() {
    if (error != null) throw error!;
  }

  @override
  Future<Venta?> getVentaByFecha(int idsucursales, DateTime fecha) async {
    _throwIfError();
    return ventaByFecha;
  }

  @override
  Future<Venta> createVenta(int idsucursales, DateTime fecha) async {
    _throwIfError();
    createVentaCalls++;
    return Venta(
      id: nextVentaId++,
      fecha: fecha,
      total: 0,
      ganancias: 0,
      descuento: 0,
      idsucursales: idsucursales,
    );
  }

  /// Como la RPC `incrementar_venta`: suma los deltas a [venta] (o a una
  /// venta en 0) y asigna `fecha` directo.
  @override
  Future<Venta> actualizarVenta(Map<String, dynamic> ventaLike, int id) async {
    _throwIfError();
    actualizaciones.add(Map<String, dynamic>.from(ventaLike));
    idsActualizados.add(id);
    final actual = venta ??
        Venta(
            id: id,
            fecha: DateTime(2024),
            total: 0,
            ganancias: 0,
            descuento: 0,
            idsucursales: 1);
    double delta(String campo) => (ventaLike[campo] as num?)?.toDouble() ?? 0;
    return venta = Venta(
      id: id,
      fecha: DateTime.tryParse(ventaLike['fecha']?.toString() ?? '') ??
          actual.fecha,
      total: actual.total + delta('total'),
      ganancias: actual.ganancias + delta('ganancias'),
      descuento: actual.descuento + delta('descuento'),
      idsucursales: actual.idsucursales,
    );
  }

  @override
  Future<List<Venta>> getVentas(int idsucursal) async {
    _throwIfError();
    getVentasCalls++;
    lastGetVentasSucursalId = idsucursal;
    return ventas;
  }

  @override
  Future<Venta> getVenta(int id) async {
    _throwIfError();
    return venta ??
        Venta(
            id: id,
            fecha: DateTime(2024),
            total: 0,
            ganancias: 0,
            descuento: 0,
            idsucursales: 1);
  }

  @override
  Future<Venta> createVentaAhora(int idsucursales) async {
    createVentaAhoraCalls++;
    return createVenta(idsucursales, DateTime.now());
  }

  @override
  Future<void> deleteVenta(int id) async {
    _throwIfError();
    ventasEliminadas.add(id);
  }

  /// Cada registrarVentaTelas (idsucursal, fecha, detalles, descuento,
  /// idOperacion), en orden. Se anota antes de fallar con [error]: así se
  /// compara la clave de un intento fallido con la del reintento.
  final List<Map<String, dynamic>> ventasRegistradas = [];

  /// Como la RPC `registrar_venta_telas`: devuelve el id de la venta del día
  /// ([nextVentaId], sin avanzarlo).
  @override
  Future<int> registrarVentaTelas({
    required int idsucursal,
    required DateTime fecha,
    required List<Map<String, dynamic>> detalles,
    required double descuento,
    String? idOperacion,
  }) async {
    ventasRegistradas.add({
      'idsucursal': idsucursal,
      'fecha': fecha,
      'detalles': detalles.map((e) => Map<String, dynamic>.from(e)).toList(),
      'descuento': descuento,
      'idOperacion': idOperacion,
    });
    _throwIfError();
    return nextVentaId;
  }
}

class FakeDetalleVentasRepository implements DetalleVentasRepository {
  /// Respuesta de getDetalleVenta.
  List<DetalleVenta> detalles;

  /// Respuesta de borrarDetalleVenta: la venta con los totales ya
  /// descontados (null = la línea ya no estaba).
  Venta? ventaTrasBorrar;

  FakeDetalleVentasRepository({this.detalles = const [], this.ventaTrasBorrar});

  final List<List<Map<String, dynamic>>> detallesCreados = [];
  final List<int> idsVentaUsados = [];
  final List<int> detallesEliminados = [];
  int? lastGetDetalleIdventa;
  Exception? error;

  @override
  Future<List<DetalleVenta>> createDetalleVenta(
      List<Map<String, dynamic>> detalleVentasLike, int idventas) async {
    if (error != null) throw error!;
    detallesCreados.add(detalleVentasLike
        .map((e) => Map<String, dynamic>.from(e))
        .toList());
    idsVentaUsados.add(idventas);
    return [];
  }

  @override
  Future<List<DetalleVenta>> getDetalleVenta(int idVenta) async {
    if (error != null) throw error!;
    lastGetDetalleIdventa = idVenta;
    return detalles;
  }

  @override
  Future<Venta?> borrarDetalleVenta(int id) async {
    if (error != null) throw error!;
    detallesEliminados.add(id);
    return ventaTrasBorrar;
  }
}

class FakeVentasApliquesRepository implements VentasApliquesRepository {
  List<VentaAplique> ventas;
  List<DetalleVentaAplique> detalle;

  FakeVentasApliquesRepository({
    this.ventas = const [],
    this.detalle = const [],
  });

  int createCalls = 0;
  int? lastIdsucursales;
  double? lastTotal;
  double? lastGanancias;
  double? lastDescuento;
  List<Map<String, dynamic>>? lastDetalles;
  int? lastGetVentasApliquesSucursalId;
  int? lastGetDetalleIdventa;
  Exception? error;

  /// La clave de cada createVentaAplique, en orden. Se anota antes de fallar
  /// con [error]: así se compara la de un intento fallido con la del
  /// reintento.
  final List<String?> idsOperacion = [];

  @override
  Future<int> createVentaAplique({
    required int idsucursales,
    required double total,
    required double ganancias,
    required double descuento,
    required List<Map<String, dynamic>> detalles,
    String? idOperacion,
  }) async {
    idsOperacion.add(idOperacion);
    if (error != null) throw error!;
    createCalls++;
    lastIdsucursales = idsucursales;
    lastTotal = total;
    lastGanancias = ganancias;
    lastDescuento = descuento;
    lastDetalles =
        detalles.map((e) => Map<String, dynamic>.from(e)).toList();
    return 1;
  }

  @override
  Future<List<VentaAplique>> getVentasApliques(int idsucursal) async {
    if (error != null) throw error!;
    lastGetVentasApliquesSucursalId = idsucursal;
    return ventas;
  }

  @override
  Future<List<DetalleVentaAplique>> getDetalleVentasApliques(
      int idventa) async {
    if (error != null) throw error!;
    lastGetDetalleIdventa = idventa;
    return detalle;
  }
}

class FakeApliquesRepository implements ApliquesRepository {
  List<Aplique> apliques;
  List<StockAplique> stock;
  List<ColorItem> colores;
  List<Produccion> detalleProduccion;
  List<ProduccionCabecera> producciones;
  List<StockConVentas> inventarioConVentas;

  FakeApliquesRepository({
    this.apliques = const [],
    this.stock = const [],
    this.colores = const [],
    this.detalleProduccion = const [],
    this.producciones = const [],
    this.inventarioConVentas = const [],
  });

  /// (sucursal, desde, hasta) de cada getInventarioConVentas.
  final List<(int, DateTime, DateTime)> inventarioConVentasPedidos = [];

  @override
  Future<List<StockConVentas>> getInventarioConVentas(
    int sucursalId, {
    required DateTime desde,
    required DateTime hasta,
  }) async {
    _throwIfError();
    inventarioConVentasPedidos.add((sucursalId, desde, hasta));
    return inventarioConVentas;
  }

  bool? lastSoloActivos;
  int getStockCalls = 0;
  int? lastGetStockSucursalId;
  int? lastGetColoresApliqueId;
  int? lastGetProduccionesSucursalId;
  int getProduccionesCalls = 0;
  int? lastGetDetalleProduccionId;
  final List<List<dynamic>> setColorApliqueCalls = [];
  final List<Map<String, dynamic>> produccionesCreadas = [];
  final List<List<int>> inventarioAgregado = [];
  final List<List<int>> inventarioRemovido = [];
  Exception? error;
  Exception? removeInventarioError;

  /// Error solo de createProduccion / solo de getStock (p. ej. el registro
  /// sale bien y falla el refresco del stock).
  Exception? createProduccionError;
  Exception? getStockError;

  /// La clave de cada createProduccion, en orden (también las que fallaron).
  final List<String?> idsOperacion = [];

  void _throwIfError() {
    if (error != null) throw error!;
  }

  @override
  Future<List<Aplique>> getApliques({bool soloActivos = true}) async {
    _throwIfError();
    lastSoloActivos = soloActivos;
    return apliques;
  }

  @override
  Future<List<StockAplique>> getStock(int sucursalId) async {
    _throwIfError();
    if (getStockError != null) throw getStockError!;
    getStockCalls++;
    lastGetStockSucursalId = sucursalId;
    return stock;
  }

  @override
  Future<List<ColorItem>> getColores() async => colores;

  @override
  Future<List<ColorItem>> getColoresAplique(int idaplique) async {
    _throwIfError();
    lastGetColoresApliqueId = idaplique;
    return colores;
  }

  @override
  Future<void> setColorAplique(int idaplique, int idcolor, bool activo) async {
    _throwIfError();
    setColorApliqueCalls.add([idaplique, idcolor, activo]);
  }

  @override
  Future<void> addInventario(
      int sucursalId, int apliqueId, int colorId) async {
    _throwIfError();
    inventarioAgregado.add([sucursalId, apliqueId, colorId]);
  }

  @override
  Future<void> removeInventario(
      int sucursalId, int apliqueId, int colorId) async {
    if (removeInventarioError != null) throw removeInventarioError!;
    _throwIfError();
    inventarioRemovido.add([sucursalId, apliqueId, colorId]);
  }

  @override
  Future<void> createProduccion({
    required int sucursalId,
    required DateTime fecha,
    required List<Map<String, dynamic>> lineas,
    String? idOperacion,
  }) async {
    idsOperacion.add(idOperacion);
    _throwIfError();
    if (createProduccionError != null) throw createProduccionError!;
    produccionesCreadas.add({
      'sucursalId': sucursalId,
      'fecha': fecha,
      'lineas':
          lineas.map((e) => Map<String, dynamic>.from(e)).toList(),
    });
  }

  @override
  Future<List<ProduccionCabecera>> getProducciones(int sucursalId) async {
    _throwIfError();
    getProduccionesCalls++;
    lastGetProduccionesSucursalId = sucursalId;
    return producciones;
  }

  @override
  Future<List<Produccion>> getDetalleProduccion(int idproduccion) async {
    _throwIfError();
    lastGetDetalleProduccionId = idproduccion;
    return detalleProduccion;
  }

  @override
  Future<Aplique> createAplique(Map<String, dynamic> apliqueLike) async {
    _throwIfError();
    return Aplique(
      id: 99,
      nombre: apliqueLike['nombre'] as String? ?? '',
      costoFabricacion:
          (apliqueLike['costo_fabricacion'] as num?)?.toDouble() ?? 0,
      tamanio: apliqueLike['tamanio'] as String? ?? '',
      activo: apliqueLike['activo'] as bool? ?? true,
    );
  }

  @override
  Future<Aplique> updateAplique(
      Map<String, dynamic> apliqueLike, int id) async {
    _throwIfError();
    return Aplique(
      id: id,
      nombre: apliqueLike['nombre'] as String? ?? '',
      costoFabricacion:
          (apliqueLike['costo_fabricacion'] as num?)?.toDouble() ?? 0,
      tamanio: apliqueLike['tamanio'] as String? ?? '',
      activo: apliqueLike['activo'] as bool? ?? true,
    );
  }
}

class FakeTelasRepository implements TelasRepository {
  List<Tela> telas;
  List<ColorItem> colores;

  FakeTelasRepository({this.telas = const [], this.colores = const []});

  bool getTelasUsado = false;
  bool getTelasPorSucursalUsado = false;
  int? lastIdsucursal;
  bool? lastSoloActivos;
  final List<List<dynamic>> setColorTelaCalls = [];
  Exception? error;

  void _throwIfError() {
    if (error != null) throw error!;
  }

  @override
  Future<List<Tela>> getTelas({bool soloActivos = true}) async {
    _throwIfError();
    getTelasUsado = true;
    lastSoloActivos = soloActivos;
    return telas;
  }

  @override
  Future<List<Tela>> getTelasPorSucursal(int idsucursal) async {
    _throwIfError();
    getTelasPorSucursalUsado = true;
    lastIdsucursal = idsucursal;
    return telas;
  }

  @override
  Future<Tela> getTela(int id) async =>
      telas.firstWhere((e) => e.id == id, orElse: () => Tela.empty());

  @override
  Future<Tela> createTela(Map<String, dynamic> telaLike) async {
    _throwIfError();
    return Tela(id: 99, nombre: telaLike['nombre'] as String? ?? '');
  }

  @override
  Future<Tela> updateTela(Map<String, dynamic> telaLike, int id) async {
    _throwIfError();
    return Tela(id: id, nombre: telaLike['nombre'] as String? ?? '');
  }

  @override
  Future<List<ColorItem>> getColoresTela(int idtela) async {
    _throwIfError();
    return colores;
  }

  @override
  Future<void> setColorTela(int idtela, int idcolor, bool activo) async {
    _throwIfError();
    setColorTelaCalls.add([idtela, idcolor, activo]);
  }
}

class FakeSucursalesRepository implements SucursalesRepository {
  List<Sucursal> sucursales;
  List<TelaSucursal> telasSucursal;

  FakeSucursalesRepository({
    this.sucursales = const [],
    this.telasSucursal = const [],
  });

  final List<List<dynamic>> setTelaSucursalCalls = [];
  bool deleteResult = true;
  Exception? error;

  void _throwIfError() {
    if (error != null) throw error!;
  }

  @override
  Future<List<Sucursal>> getSucursales() async {
    _throwIfError();
    return sucursales;
  }

  @override
  Future<Sucursal> getSucursal(int id) async =>
      sucursales.firstWhere((e) => e.id == id,
          orElse: () => Sucursal.empty());

  @override
  Future<Sucursal> createSucursal(Map<String, dynamic> sucursalLike) async {
    _throwIfError();
    return Sucursal(id: 99, nombre: sucursalLike['nombre'] as String? ?? '');
  }

  @override
  Future<Sucursal> updateSucursal(
      Map<String, dynamic> sucursalLike, int id) async {
    _throwIfError();
    return Sucursal(id: id, nombre: sucursalLike['nombre'] as String? ?? '');
  }

  @override
  Future<bool> deleteSucursal(int id) async {
    _throwIfError();
    return deleteResult;
  }

  @override
  Future<List<TelaSucursal>> getTelasSucursal(int idsucursal) async {
    _throwIfError();
    return telasSucursal;
  }

  @override
  Future<void> setTelaSucursal(
      int idtela, int idsucursal, bool activo) async {
    _throwIfError();
    setTelaSucursalCalls.add([idtela, idsucursal, activo]);
  }
}

class FakeColoresRepository implements ColoresRepository {
  List<ColorItem> colores;

  FakeColoresRepository({this.colores = const []});

  Map<String, dynamic>? creado;
  Map<String, dynamic>? actualizado;
  int? eliminado;
  bool deleteResult = true;
  Exception? error;

  void _throwIfError() {
    if (error != null) throw error!;
  }

  @override
  Future<List<ColorItem>> getColores({bool soloActivos = true}) async {
    _throwIfError();
    return colores;
  }

  @override
  Future<ColorItem> createColor(Map<String, dynamic> colorLike) async {
    _throwIfError();
    creado = colorLike;
    return ColorItem(
        id: 99, nombre: colorLike['nombre'] as String? ?? '', hex: colorLike['hex'] as String? ?? '');
  }

  @override
  Future<ColorItem> updateColor(Map<String, dynamic> colorLike, int id) async {
    _throwIfError();
    actualizado = colorLike;
    return ColorItem(
        id: id, nombre: colorLike['nombre'] as String? ?? '', hex: colorLike['hex'] as String? ?? '');
  }

  @override
  Future<bool> deleteColor(int id) async {
    _throwIfError();
    eliminado = id;
    return deleteResult;
  }
}

class FakeDashboardRepository implements DashboardRepository {
  List<TopProducto> topTelas;
  List<TopProducto> topApliques;
  ResumenVentas resumenTelas;
  ResumenVentas resumenApliques;

  FakeDashboardRepository({
    this.topTelas = const [],
    this.topApliques = const [],
    this.resumenTelas =
        const ResumenVentas(total: 0, ganancias: 0, descuento: 0),
    this.resumenApliques =
        const ResumenVentas(total: 0, ganancias: 0, descuento: 0),
  });

  /// Rangos (desde, hasta) recibidos por cada llamada.
  final List<List<DateTime>> rangos = [];

  @override
  Future<List<TopProducto>> getTopProductos(
      {required DateTime desde, required DateTime hasta}) async {
    rangos.add([desde, hasta]);
    return topTelas;
  }

  @override
  Future<List<TopProducto>> getTopApliques(
      {required DateTime desde, required DateTime hasta}) async {
    rangos.add([desde, hasta]);
    return topApliques;
  }

  @override
  Future<ResumenVentas> getResumenVentas(
      {required DateTime desde, required DateTime hasta}) async {
    rangos.add([desde, hasta]);
    return resumenTelas;
  }

  @override
  Future<ResumenVentas> getResumenVentasApliques(
      {required DateTime desde, required DateTime hasta}) async {
    rangos.add([desde, hasta]);
    return resumenApliques;
  }
}

/// Fake en memoria: acepta solo [emailOk]/[passwordOk].
class FakeAuthRepository implements AuthRepository {
  static const emailOk = 'dueno@huantex.com';
  static const passwordOk = 'secreta';

  final _cambios = StreamController<bool>.broadcast();
  String? _email;
  bool sinConexion = false;
  int intentos = 0;

  @override
  bool get haySesion => _email != null;

  @override
  String? get email => _email;

  @override
  Stream<bool> get cambiosDeSesion => _cambios.stream;

  @override
  Future<void> iniciarSesion(
      {required String email, required String password}) async {
    intentos++;
    if (sinConexion) throw const AuthFallo('Sin conexión');
    if (email != emailOk || password != passwordOk) {
      throw const AuthFallo('Email o contraseña incorrectos');
    }
    _email = email;
    _cambios.add(true);
  }

  @override
  Future<void> cerrarSesion() async {
    _email = null;
    _cambios.add(false);
  }
}

class FakeFotosRepository implements FotosRepository {
  String nombre;
  List<Foto> fotos;

  FakeFotosRepository({this.nombre = '', List<Foto>? fotos})
      : fotos = [...?fotos];

  final List<(ProductoConFotos, int)> getFotosCalls = [];
  final List<(ProductoConFotos, int, FotoElegida)> subirCalls = [];
  final List<(ProductoConFotos, int)> quitarCalls = [];
  Exception? error;
  Exception? errorAlSubir;
  int _proximoId = 100;

  void _throwIfError() {
    if (error != null) throw error!;
  }

  @override
  Future<String> getNombre(ProductoConFotos producto, int id) async {
    _throwIfError();
    return nombre;
  }

  @override
  Future<List<Foto>> getFotos(ProductoConFotos producto, int id) async {
    _throwIfError();
    getFotosCalls.add((producto, id));
    return fotos;
  }

  @override
  Future<Foto> subirFoto(
      ProductoConFotos producto, int id, FotoElegida foto) async {
    _throwIfError();
    if (errorAlSubir != null) throw errorAlSubir!;
    subirCalls.add((producto, id, foto));
    final nueva = Foto(id: _proximoId++, url: 'https://example.com/$_proximoId.jpg');
    fotos = [...fotos, nueva];
    return nueva;
  }

  @override
  Future<void> quitarFoto(ProductoConFotos producto, int idfoto) async {
    _throwIfError();
    quitarCalls.add((producto, idfoto));
    fotos = fotos.where((f) => f.id != idfoto).toList();
  }
}
