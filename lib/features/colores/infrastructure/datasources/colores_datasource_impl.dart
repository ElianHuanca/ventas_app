import 'package:textiles_app/config/supabase/supabase_config.dart';
import 'package:textiles_app/features/apliques/domain/entities/color_item.dart';
import '../../domain/domain.dart';

class ColoresDatasourceImpl implements ColoresDatasource {
  final _db = SupabaseConfig.client;
  static const _table = 'colores';

  @override
  Future<List<ColorItem>> getColores({bool soloActivos = true}) async {
    var query = _db.from(_table).select();
    if (soloActivos) query = query.eq('activo', true);
    final list = await query.order('nombre');
    return list.map<ColorItem>(_toEntity).toList();
  }

  @override
  Future<ColorItem> createColor(Map<String, dynamic> colorLike) async {
    final data = Map<String, dynamic>.from(colorLike)..remove('id');
    final row = await _db.from(_table).insert(data).select().single();
    return _toEntity(row);
  }

  @override
  Future<ColorItem> updateColor(Map<String, dynamic> colorLike, int id) async {
    final data = Map<String, dynamic>.from(colorLike)..remove('id');
    final row =
        await _db.from(_table).update(data).eq('id', id).select().single();
    return _toEntity(row);
  }

  @override
  Future<bool> deleteColor(int id) async {
    final rows = await _db
        .from(_table)
        .update({'activo': false})
        .eq('id', id)
        .select('id');
    return rows.isNotEmpty;
  }

  ColorItem _toEntity(Map<String, dynamic> json) => ColorItem(
        id: json['id'] as int,
        nombre: json['nombre'] ?? '',
        hex: json['hex'] ?? '',
      );
}
