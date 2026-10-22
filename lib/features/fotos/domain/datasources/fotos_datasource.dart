import '../entities/foto.dart';

abstract class FotosDatasource {
  Future<String> getNombre(ProductoConFotos producto, int id);
  Future<List<Foto>> getFotos(ProductoConFotos producto, int id);
  Future<Foto> subirFoto(ProductoConFotos producto, int id, FotoElegida foto);
  Future<void> quitarFoto(ProductoConFotos producto, int idfoto);
}
