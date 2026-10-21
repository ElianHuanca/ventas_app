import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/colores/domain/domain.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';

/// Fakes en memoria de los datasources de domain, para testear los
/// `*RepositoryImpl` (que solo delegan) sin Supabase.
///
/// Cada llamada queda en [FakeDatasource.llamadas] como
/// `[método, ...argumentos]`, en orden, para compararla con `expect(..., [...])`
/// (igualdad profunda). Si [FakeDatasource.error] no es null, todos los
/// métodos lo lanzan después de registrar la llamada.
abstract class FakeDatasource {
  final List<List<Object?>> llamadas = [];
  Exception? error;

  T registrar<T>(String metodo, List<Object?> argumentos, T respuesta) {
    llamadas.add([metodo, ...argumentos]);
    if (error != null) throw error!;
    return respuesta;
  }
}

class FakeApliquesDatasource extends FakeDatasource
    implements ApliquesDatasource {
  List<Aplique> apliques = [Aplique(id: 1, nombre: 'Flor')];
  Aplique aplique = Aplique(id: 7, nombre: 'Luna');
  List<StockAplique> stock = const [
    StockAplique(
        apliqueId: 1, colorId: 2, colorNombre: 'Rojo', hex: 'FF0000', stock: 5),
  ];
  List<ColorItem> colores = const [ColorItem(id: 2, nombre: 'Rojo')];
  List<ProduccionCabecera> producciones = [
    ProduccionCabecera(id: 3, fecha: DateTime(2026, 10, 1)),
  ];
  List<Produccion> detalleProduccion = const [
    Produccion(
      id: 4,
      fecha: '2026-10-01',
      sucursalNombre: 'Centro',
      apliqueNombre: 'Flor',
      colorNombre: 'Rojo',
      cantidad: 6,
    ),
  ];

  @override
  Future<List<Aplique>> getApliques({bool soloActivos = true}) async =>
      registrar('getApliques', [soloActivos], apliques);

  @override
  Future<Aplique> createAplique(Map<String, dynamic> apliqueLike) async =>
      registrar('createAplique', [apliqueLike], aplique);

  @override
  Future<Aplique> updateAplique(
          Map<String, dynamic> apliqueLike, int id) async =>
      registrar('updateAplique', [apliqueLike, id], aplique);

  @override
  Future<List<StockAplique>> getStock(int sucursalId) async =>
      registrar('getStock', [sucursalId], stock);

  @override
  Future<List<ColorItem>> getColores() async =>
      registrar('getColores', [], colores);

  @override
  Future<List<ColorItem>> getColoresAplique(int idaplique) async =>
      registrar('getColoresAplique', [idaplique], colores);

  @override
  Future<void> setColorAplique(int idaplique, int idcolor, bool activo) async =>
      registrar('setColorAplique', [idaplique, idcolor, activo], null);

  @override
  Future<void> addInventario(
          int sucursalId, int apliqueId, int colorId) async =>
      registrar('addInventario', [sucursalId, apliqueId, colorId], null);

  @override
  Future<void> removeInventario(
          int sucursalId, int apliqueId, int colorId) async =>
      registrar('removeInventario', [sucursalId, apliqueId, colorId], null);

  List<StockConVentas> inventarioConVentas = const [
    StockConVentas(
      apliqueId: 1,
      aplique: 'Flor',
      colorId: 2,
      color: 'Rojo',
      hex: 'FF0000',
      stock: 3,
      vendidas: 8,
    ),
  ];

  @override
  Future<List<StockConVentas>> getInventarioConVentas(
    int sucursalId, {
    required DateTime desde,
    required DateTime hasta,
  }) async =>
      registrar('getInventarioConVentas', [sucursalId, desde, hasta],
          inventarioConVentas);

  @override
  Future<void> createProduccion({
    required int sucursalId,
    required DateTime fecha,
    required List<Map<String, dynamic>> lineas,
  }) async =>
      registrar('createProduccion', [sucursalId, fecha, lineas], null);

  @override
  Future<List<ProduccionCabecera>> getProducciones(int sucursalId) async =>
      registrar('getProducciones', [sucursalId], producciones);

  @override
  Future<List<Produccion>> getDetalleProduccion(int idproduccion) async =>
      registrar('getDetalleProduccion', [idproduccion], detalleProduccion);
}

class FakeVentasApliquesDatasource extends FakeDatasource
    implements VentasApliquesDatasource {
  int idventa = 42;
  List<VentaAplique> ventas = [VentaAplique(id: 42, fecha: DateTime(2026))];
  List<DetalleVentaAplique> detalle = const [
    DetalleVentaAplique(
        id: 1, nombre: 'Flor (Rojo)', cantidad: 2, precio: 12, total: 24),
  ];

  @override
  Future<int> createVentaAplique({
    required int idsucursales,
    required double total,
    required double ganancias,
    required double descuento,
    required List<Map<String, dynamic>> detalles,
  }) async =>
      registrar('createVentaAplique',
          [idsucursales, total, ganancias, descuento, detalles], idventa);

  @override
  Future<List<VentaAplique>> getVentasApliques(int idsucursal) async =>
      registrar('getVentasApliques', [idsucursal], ventas);

  @override
  Future<List<DetalleVentaAplique>> getDetalleVentasApliques(
          int idventa) async =>
      registrar('getDetalleVentasApliques', [idventa], detalle);
}

class FakeColoresDatasource extends FakeDatasource
    implements ColoresDatasource {
  List<ColorItem> colores = const [ColorItem(id: 1, nombre: 'Rojo')];
  ColorItem color = const ColorItem(id: 9, nombre: 'Azul', hex: '0000FF');
  bool eliminado = true;

  @override
  Future<List<ColorItem>> getColores({bool soloActivos = true}) async =>
      registrar('getColores', [soloActivos], colores);

  @override
  Future<ColorItem> createColor(Map<String, dynamic> colorLike) async =>
      registrar('createColor', [colorLike], color);

  @override
  Future<ColorItem> updateColor(Map<String, dynamic> colorLike, int id) async =>
      registrar('updateColor', [colorLike, id], color);

  @override
  Future<bool> deleteColor(int id) async =>
      registrar('deleteColor', [id], eliminado);
}

class FakeDashboardDatasource extends FakeDatasource
    implements DashboardDatasource {
  List<TopProducto> topTelas = const [
    TopProducto(nombre: 'Lino', totalVendido: 100, totalCantidad: 4),
  ];
  List<TopProducto> topApliques = const [
    TopProducto(nombre: 'Flor', totalVendido: 50, totalCantidad: 5),
  ];
  ResumenVentas resumenTelas =
      const ResumenVentas(total: 100, ganancias: 40, descuento: 2);
  ResumenVentas resumenApliques =
      const ResumenVentas(total: 50, ganancias: 20, descuento: 0);

  @override
  Future<List<TopProducto>> getTopProductos(
          {required DateTime desde, required DateTime hasta}) async =>
      registrar('getTopProductos', [desde, hasta], topTelas);

  @override
  Future<List<TopProducto>> getTopApliques(
          {required DateTime desde, required DateTime hasta}) async =>
      registrar('getTopApliques', [desde, hasta], topApliques);

  @override
  Future<ResumenVentas> getResumenVentas(
          {required DateTime desde, required DateTime hasta}) async =>
      registrar('getResumenVentas', [desde, hasta], resumenTelas);

  @override
  Future<ResumenVentas> getResumenVentasApliques(
          {required DateTime desde, required DateTime hasta}) async =>
      registrar('getResumenVentasApliques', [desde, hasta], resumenApliques);
}

class FakeSucursalesDatasource extends FakeDatasource
    implements SucursalesDatasource {
  List<Sucursal> sucursales = [Sucursal(id: 1, nombre: 'Centro')];
  Sucursal sucursal = Sucursal(id: 5, nombre: 'Norte');
  bool eliminada = true;
  List<TelaSucursal> telasSucursal = const [
    TelaSucursal(idtela: 3, nombre: 'Lino', disponible: true),
  ];

  @override
  Future<List<Sucursal>> getSucursales() async =>
      registrar('getSucursales', [], sucursales);

  @override
  Future<Sucursal> getSucursal(int id) async =>
      registrar('getSucursal', [id], sucursal);

  @override
  Future<Sucursal> createSucursal(Map<String, dynamic> sucursalLike) async =>
      registrar('createSucursal', [sucursalLike], sucursal);

  @override
  Future<Sucursal> updateSucursal(
          Map<String, dynamic> sucursalLike, int id) async =>
      registrar('updateSucursal', [sucursalLike, id], sucursal);

  @override
  Future<bool> deleteSucursal(int id) async =>
      registrar('deleteSucursal', [id], eliminada);

  @override
  Future<List<TelaSucursal>> getTelasSucursal(int idsucursal) async =>
      registrar('getTelasSucursal', [idsucursal], telasSucursal);

  @override
  Future<void> setTelaSucursal(int idtela, int idsucursal, bool activo) async =>
      registrar('setTelaSucursal', [idtela, idsucursal, activo], null);
}

class FakeTelasDatasource extends FakeDatasource implements TelasDatasource {
  List<Tela> telas = [Tela(id: 1, nombre: 'Lino')];
  Tela tela = Tela(id: 8, nombre: 'Seda', precxmen: 30);
  List<ColorItem> colores = const [
    ColorItem(id: 2, nombre: 'Rojo', vinculado: true),
  ];

  @override
  Future<List<Tela>> getTelas({bool soloActivos = true}) async =>
      registrar('getTelas', [soloActivos], telas);

  @override
  Future<List<Tela>> getTelasPorSucursal(int idsucursal) async =>
      registrar('getTelasPorSucursal', [idsucursal], telas);

  @override
  Future<Tela> getTela(int id) async => registrar('getTela', [id], tela);

  @override
  Future<Tela> createTela(Map<String, dynamic> telaLike) async =>
      registrar('createTela', [telaLike], tela);

  @override
  Future<Tela> updateTela(Map<String, dynamic> telaLike, int id) async =>
      registrar('updateTela', [telaLike, id], tela);

  @override
  Future<List<ColorItem>> getColoresTela(int idtela) async =>
      registrar('getColoresTela', [idtela], colores);

  @override
  Future<void> setColorTela(int idtela, int idcolor, bool activo) async =>
      registrar('setColorTela', [idtela, idcolor, activo], null);
}

class FakeVentasDatasource extends FakeDatasource implements VentasDatasource {
  List<Venta> ventas = [_venta(1)];
  Venta venta = _venta(2);

  /// Respuesta de getVentaByFecha (null = ese día no tiene venta).
  Venta? ventaByFecha;

  static Venta _venta(int id) => Venta(
        id: id,
        fecha: DateTime(2026, 10, 1),
        total: 100,
        ganancias: 30,
        descuento: 0,
        idsucursales: 1,
      );

  @override
  Future<List<Venta>> getVentas(int idsucursal) async =>
      registrar('getVentas', [idsucursal], ventas);

  @override
  Future<Venta> getVenta(int id) async => registrar('getVenta', [id], venta);

  @override
  Future<Venta?> getVentaByFecha(int idsucursales, DateTime fecha) async =>
      registrar('getVentaByFecha', [idsucursales, fecha], ventaByFecha);

  @override
  Future<Venta> createVentaAhora(int idsucursales) async =>
      registrar('createVentaAhora', [idsucursales], venta);

  @override
  Future<Venta> createVenta(int idsucursales, DateTime fecha) async =>
      registrar('createVenta', [idsucursales, fecha], venta);

  @override
  Future<Venta> actualizarVenta(Map<String, dynamic> ventaLike, int id) async =>
      registrar('actualizarVenta', [ventaLike, id], venta);

  @override
  Future<void> deleteVenta(int id) async =>
      registrar('deleteVenta', [id], null);
}

class FakeDetalleVentasDatasource extends FakeDatasource
    implements DetalleVentasDatasource {
  List<DetalleVenta> detalles = const [
    DetalleVenta(id: 1, precio: 25, cantidad: 2, total: 50, idtelas: 3),
  ];
  DetalleVenta borrado =
      const DetalleVenta(id: 9, precio: 30, cantidad: 1, total: 30, idtelas: 4);

  @override
  Future<List<DetalleVenta>> getDetalleVenta(int idventas) async =>
      registrar('getDetalleVenta', [idventas], detalles);

  @override
  Future<List<DetalleVenta>> createDetalleVenta(
          List<Map<String, dynamic>> detalleVentasLike, int idventas) async =>
      registrar('createDetalleVenta', [detalleVentasLike, idventas], detalles);

  @override
  Future<DetalleVenta> deleteDetalleVenta(int id) async =>
      registrar('deleteDetalleVenta', [id], borrado);
}
