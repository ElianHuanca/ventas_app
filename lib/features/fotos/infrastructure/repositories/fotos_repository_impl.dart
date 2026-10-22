import '../../domain/domain.dart';

class FotosRepositoryImpl implements FotosRepository {
  final FotosDatasource datasource;

  FotosRepositoryImpl(this.datasource);

  @override
  Future<String> getNombre(ProductoConFotos producto, int id) =>
      datasource.getNombre(producto, id);

  @override
  Future<List<Foto>> getFotos(ProductoConFotos producto, int id) =>
      datasource.getFotos(producto, id);

  @override
  Future<Foto> subirFoto(ProductoConFotos producto, int id, FotoElegida foto) =>
      datasource.subirFoto(producto, id, foto);

  @override
  Future<void> quitarFoto(ProductoConFotos producto, int idfoto) =>
      datasource.quitarFoto(producto, idfoto);
}
