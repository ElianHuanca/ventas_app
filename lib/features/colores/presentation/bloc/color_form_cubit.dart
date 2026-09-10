import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/apliques/domain/entities/color_item.dart';

class ColorFormState {
  final int id;
  final String nombre;
  final String hex;

  ColorFormState({this.id = 0, this.nombre = '', this.hex = ''});

  ColorFormState copyWith({int? id, String? nombre, String? hex}) =>
      ColorFormState(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        hex: hex ?? this.hex,
      );
}

class ColorFormCubit extends Cubit<ColorFormState> {
  final Future<bool> Function(Map<String, dynamic>) onCreateCallback;
  final Future<bool> Function(Map<String, dynamic>) onUpdateCallback;
  final Future<bool> Function(int) onDeleteCallback;

  ColorFormCubit({
    required this.onCreateCallback,
    required this.onUpdateCallback,
    required this.onDeleteCallback,
    required ColorItem color,
  }) : super(ColorFormState(
          id: color.id,
          nombre: color.nombre,
          hex: color.hex,
        ));

  /// Hex normalizado: sin '#', mayúsculas, 6 dígitos. Null si inválido.
  static String? normalizarHex(String value) {
    final limpio = value.replaceAll('#', '').trim().toUpperCase();
    if (limpio.length != 6) return null;
    if (int.tryParse(limpio, radix: 16) == null) return null;
    return limpio;
  }

  Future<bool> onSubmit({required bool isUpdate}) async {
    final nombre = state.nombre.trim();
    if (nombre.isEmpty) return false;
    final hex = normalizarHex(state.hex);
    if (hex == null) return false;

    final colorLike = {'id': state.id, 'nombre': nombre, 'hex': hex};
    try {
      return isUpdate
          ? await onUpdateCallback(colorLike)
          : await onCreateCallback(colorLike);
    } catch (_) {
      return false;
    }
  }

  Future<bool> onDelete() async {
    try {
      return await onDeleteCallback(state.id);
    } catch (_) {
      return false;
    }
  }

  void onNombreChanged(String value) => emit(state.copyWith(nombre: value));
  void onHexChanged(String value) => emit(state.copyWith(hex: value));
}
