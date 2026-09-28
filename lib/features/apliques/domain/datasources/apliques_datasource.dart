import '../entities/aplique.dart';
import '../entities/color_item.dart';
import '../entities/produccion.dart';
import '../entities/produccion_cabecera.dart';
import '../entities/stock_aplique.dart';

abstract class ApliquesDatasource {
  Future<List<Aplique>> getApliques({bool soloActivos = true});
  Future<Aplique> createAplique(Map<String, dynamic> apliqueLike);
  Future<Aplique> updateAplique(Map<String, dynamic> apliqueLike, int id);

  Future<List<StockAplique>> getStock(int sucursalId);
  Future<List<ColorItem>> getColores();
  Future<List<ColorItem>> getColoresAplique(int idaplique);
  Future<void> setColorAplique(int idaplique, int idcolor, bool activo);

  /// Vincula un aplique+color a una sucursal (fila de inventario con stock 0).
  Future<void> addInventario(int sucursalId, int apliqueId, int colorId);

  /// Quita la vinculación. Lanza excepción si la fila tiene stock > 0.
  Future<void> removeInventario(int sucursalId, int apliqueId, int colorId);

  /// Registra una producción (lote de líneas) y sube el stock en inventario.
  /// Cada línea es {idaplique, idcolor, cantidad}.
  Future<void> createProduccion({
    required int sucursalId,
    required DateTime fecha,
    required List<Map<String, dynamic>> lineas,
  });
  Future<List<ProduccionCabecera>> getProducciones(int sucursalId);
  Future<List<Produccion>> getDetalleProduccion(int idproduccion);
}
