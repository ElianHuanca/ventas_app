import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class ApliqueFormState {
  final int id;
  final String nombre;
  final String tamanio;
  final String costoFabricacion;
  final bool activo;

  ApliqueFormState({
    this.id = 0,
    this.nombre = '',
    this.tamanio = '',
    this.costoFabricacion = '',
    this.activo = true,
  });

  ApliqueFormState copyWith({
    int? id,
    String? nombre,
    String? tamanio,
    String? costoFabricacion,
    bool? activo,
  }) =>
      ApliqueFormState(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        tamanio: tamanio ?? this.tamanio,
        costoFabricacion: costoFabricacion ?? this.costoFabricacion,
        activo: activo ?? this.activo,
      );
}

class ApliqueFormCubit extends Cubit<ApliqueFormState> {
  final Future<bool> Function(Map<String, dynamic>) onCreateCallback;
  final Future<bool> Function(Map<String, dynamic>) onUpdateCallback;

  ApliqueFormCubit({
    required this.onCreateCallback,
    required this.onUpdateCallback,
    required Aplique aplique,
  }) : super(ApliqueFormState(
          id: aplique.id,
          nombre: aplique.nombre,
          tamanio: aplique.tamanio,
          costoFabricacion: aplique.costoFabricacion == 0
              ? ''
              : aplique.costoFabricacion.toString(),
          activo: aplique.activo,
        ));

  Future<bool> onSubmit({required bool isUpdate}) async {
    if (state.nombre.trim().isEmpty) return false;
    final costo = double.tryParse(state.costoFabricacion);
    if (costo == null || costo < 0) return false;

    final apliqueLike = {
      'id': state.id,
      'nombre': state.nombre.trim(),
      'tamanio': state.tamanio.isEmpty ? null : state.tamanio,
      'costo_fabricacion': costo,
      'activo': state.activo,
    };
    try {
      return isUpdate
          ? await onUpdateCallback(apliqueLike)
          : await onCreateCallback(apliqueLike);
    } catch (_) {
      return false;
    }
  }

  void onNombreChanged(String value) => emit(state.copyWith(nombre: value));
  void onTamanioChanged(String? value) =>
      emit(state.copyWith(tamanio: value ?? ''));
  void onCostoChanged(String value) =>
      emit(state.copyWith(costoFabricacion: value));
  void onActivoChanged(bool value) => emit(state.copyWith(activo: value));
}
