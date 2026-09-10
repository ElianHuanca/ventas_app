import 'package:textiles_app/features/apliques/domain/entities/color_item.dart';
import '../domain.dart';

abstract class TelasDatasource {
  Future<List<Tela>> getTelas();
  Future<List<Tela>> getTelasPorSucursal(int idsucursal);
  Future<Tela> getTela(int id);
  Future<Tela> createTela(Map<String, dynamic> telaLike);
  Future<Tela> updateTela(Map<String, dynamic> telaLike,int id);  
  Future<bool> deleteTela(int id);
  Future<List<ColorItem>> getColoresTela(int idtela);
  Future<void> setColorTela(int idtela, int idcolor, bool activo);
}