import 'package:textiles_app/features/apliques/domain/entities/color_item.dart';
import '../../domain/domain.dart';

class TelasRepositoryImpl implements TelasRepository {
  final TelasDatasource datasource;

  TelasRepositoryImpl(this.datasource);

  @override
  Future<List<Tela>> getTelas() {
    return datasource.getTelas();
  }

  @override
  Future<List<Tela>> getTelasPorSucursal(int idsucursal) {
    return datasource.getTelasPorSucursal(idsucursal);
  }
  
  @override
  Future<Tela> createTela(Map<String, dynamic> telaLike) {
    return datasource.createTela(telaLike);
  }
  
  @override
  Future<Tela> updateTela(Map<String, dynamic> telaLike,int id) {   
    return datasource.updateTela(telaLike,id);
  }

  @override
  Future<bool> deleteTela(int id) {   
    return datasource.deleteTela(id);
  }
  
  @override
  Future<Tela> getTela(int id) {
    return datasource.getTela(id);
  }

  @override
  Future<List<ColorItem>> getColoresTela(int idtela) {
    return datasource.getColoresTela(idtela);
  }

  @override
  Future<void> setColorTela(int idtela, int idcolor, bool activo) {
    return datasource.setColorTela(idtela, idcolor, activo);
  }
}
