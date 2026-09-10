import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/colores/domain/domain.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';

/// Fakes en memoria de los repositorios de domain.
/// Registran las llamadas recibidas para poder verificarlas en los tests
/// y permiten configurar respuestas y errores sin tocar Supabase.

class FakeVentasRepository implements VentasRepository {
  /// Respuesta configurable de getVentaByFecha (null = no existe venta).
  Venta? ventaByFecha;

  int nextVentaId = 10;
  int createVentaCalls = 0;
  int createVentaAhoraCalls = 0;
  List<Map<String, dynamic>> actualizaciones = [];
  List<int> idsActualizados = [];
  Object? error;

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

  @override
  Future<Venta> actualizarVenta(Map<String, dynamic> ventaLike, int id) async {
    _throwIfError();
    actualizaciones.add(Map<String, dynamic>.from(ventaLike));
    idsActualizados.add(id);
    return Venta(
      id: id,
      fecha: DateTime.tryParse(ventaLike['fecha']?.toString() ?? '') ??
          DateTime(2024),
      total: (ventaLike['total'] as num?)?.toDouble() ?? 0,
      ganancias: (ventaLike['ganancias'] as num?)?.toDouble() ?? 0,
      descuento: (ventaLike['descuento'] as num?)?.toDouble() ?? 0,
      idsucursales: 1,
    );
  }

  @override
  Future<List<Venta>> getVentas(int idsucursal) async => [];

  @override
  Future<Venta> getVenta(int id) async => Venta(
      id: id,
      fecha: DateTime(2024),
      total: 0,
      ganancias: 0,
      descuento: 0,
      idsucursales: 1);

  @override
  Future<Venta> createVentaAhora(int idsucursales) async {
    createVentaAhoraCalls++;
    return createVenta(idsucursales, DateTime.now());
  }

  @override
  Future<void> deleteVenta(int id) async {}
}

class FakeDetalleVentasRepository implements DetalleVentasRepository {
  final List<List<Map<String, dynamic>>> detallesCreados = [];
  final List<int> idsVentaUsados = [];
  Object? error;

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
  Future<List<DetalleVenta>> getDetalleVenta(int idVenta) async => [];

  @override
  Future<DetalleVenta> deleteDetalleVenta(int id) async =>
      DetalleVenta(id: id, precio: 0, cantidad: 0, idtelas: 0);
}

class FakeVentasApliquesRepository implements VentasApliquesRepository {
  int createCalls = 0;
  int? lastIdsucursales;
  double? lastTotal;
  double? lastGanancias;
  double? lastDescuento;
  List<Map<String, dynamic>>? lastDetalles;
  Object? error;

  @override
  Future<int> createVentaAplique({
    required int idsucursales,
    required double total,
    required double ganancias,
    required double descuento,
    required List<Map<String, dynamic>> detalles,
  }) async {
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
}

class FakeApliquesRepository implements ApliquesRepository {
  List<Aplique> apliques;
  List<StockAplique> stock;
  List<ColorItem> colores;
  List<Produccion> producciones;

  FakeApliquesRepository({
    this.apliques = const [],
    this.stock = const [],
    this.colores = const [],
    this.producciones = const [],
  });

  bool? lastSoloActivos;
  int getStockCalls = 0;
  int? lastGetColoresApliqueId;
  final List<List<dynamic>> setColorApliqueCalls = [];
  final List<Map<String, dynamic>> produccionesCreadas = [];
  final List<List<int>> inventarioAgregado = [];
  final List<List<int>> inventarioRemovido = [];
  Object? error;
  Object? removeInventarioError;

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
    getStockCalls++;
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
    required int apliqueId,
    required int colorId,
    required double cantidad,
  }) async {
    _throwIfError();
    produccionesCreadas.add({
      'sucursalId': sucursalId,
      'apliqueId': apliqueId,
      'colorId': colorId,
      'cantidad': cantidad,
    });
  }

  @override
  Future<List<Produccion>> getProducciones({int limit = 20}) async {
    _throwIfError();
    return producciones;
  }

  @override
  Future<Aplique> createAplique(Map<String, dynamic> apliqueLike) async {
    _throwIfError();
    return Aplique(
      id: 99,
      nombre: apliqueLike['nombre'] ?? '',
      costoFabricacion:
          (apliqueLike['costo_fabricacion'] as num?)?.toDouble() ?? 0,
      tamanio: apliqueLike['tamanio'] ?? '',
      activo: apliqueLike['activo'] ?? true,
    );
  }

  @override
  Future<Aplique> updateAplique(
      Map<String, dynamic> apliqueLike, int id) async {
    _throwIfError();
    return Aplique(
      id: id,
      nombre: apliqueLike['nombre'] ?? '',
      costoFabricacion:
          (apliqueLike['costo_fabricacion'] as num?)?.toDouble() ?? 0,
      tamanio: apliqueLike['tamanio'] ?? '',
      activo: apliqueLike['activo'] ?? true,
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
  final List<List<dynamic>> setColorTelaCalls = [];
  bool deleteResult = true;
  Object? error;

  void _throwIfError() {
    if (error != null) throw error!;
  }

  @override
  Future<List<Tela>> getTelas() async {
    _throwIfError();
    getTelasUsado = true;
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
    return Tela(id: 99, nombre: telaLike['nombre'] ?? '');
  }

  @override
  Future<Tela> updateTela(Map<String, dynamic> telaLike, int id) async {
    _throwIfError();
    return Tela(id: id, nombre: telaLike['nombre'] ?? '');
  }

  @override
  Future<bool> deleteTela(int id) async {
    _throwIfError();
    return deleteResult;
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
  Object? error;

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
    return Sucursal(id: 99, nombre: sucursalLike['nombre'] ?? '');
  }

  @override
  Future<Sucursal> updateSucursal(
      Map<String, dynamic> sucursalLike, int id) async {
    _throwIfError();
    return Sucursal(id: id, nombre: sucursalLike['nombre'] ?? '');
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
  Object? error;

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
        id: 99, nombre: colorLike['nombre'] ?? '', hex: colorLike['hex'] ?? '');
  }

  @override
  Future<ColorItem> updateColor(Map<String, dynamic> colorLike, int id) async {
    _throwIfError();
    actualizado = colorLike;
    return ColorItem(
        id: id, nombre: colorLike['nombre'] ?? '', hex: colorLike['hex'] ?? '');
  }

  @override
  Future<bool> deleteColor(int id) async {
    _throwIfError();
    eliminado = id;
    return deleteResult;
  }
}
