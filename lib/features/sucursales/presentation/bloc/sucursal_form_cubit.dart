import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class SucursalFormState {
  final int id;
  final String nombre;

  SucursalFormState({this.id = 0, this.nombre = ''});

  SucursalFormState copyWith({int? id, String? nombre}) =>
      SucursalFormState(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
      );
}

class SucursalFormCubit extends Cubit<SucursalFormState> {
  final Future<bool> Function(Map<String, dynamic>) onCreateCallback;
  final Future<bool> Function(Map<String, dynamic>) onUpdateCallback;
  final Future<bool> Function(int) onDeleteCallback;

  SucursalFormCubit({
    required this.onCreateCallback,
    required this.onUpdateCallback,
    required this.onDeleteCallback,
    required Sucursal sucursal,
  }) : super(SucursalFormState(
          id: sucursal.id,
          nombre: sucursal.nombre,
        ));

  Future<bool> onSubmit({required bool isUpdate}) async {
    final nombre = state.nombre.trim();
    if (nombre.isEmpty) return false;
    final sucursalLike = {'id': state.id, 'nombre': nombre};
    try {
      return isUpdate
          ? await onUpdateCallback(sucursalLike)
          : await onCreateCallback(sucursalLike);
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

  void onNombreChanged(String value) {
    emit(state.copyWith(nombre: value));
  }
}
