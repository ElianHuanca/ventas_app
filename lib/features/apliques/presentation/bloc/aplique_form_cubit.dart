import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class ApliqueFormState {
  final int id;
  final String nombre;
  final String anchoCm;
  final String altoCm;
  final String costoFabricacion;
  final bool activo;

  ApliqueFormState({
    this.id = 0,
    this.nombre = '',
    this.anchoCm = '',
    this.altoCm = '',
    this.costoFabricacion = '',
    this.activo = true,
  });

  ApliqueFormState copyWith({
    int? id,
    String? nombre,
    String? anchoCm,
    String? altoCm,
    String? costoFabricacion,
    bool? activo,
  }) =>
      ApliqueFormState(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        anchoCm: anchoCm ?? this.anchoCm,
        altoCm: altoCm ?? this.altoCm,
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
          anchoCm: aplique.anchoCm?.toString() ?? '',
          altoCm: aplique.altoCm?.toString() ?? '',
          costoFabricacion: aplique.costoFabricacion == 0
              ? ''
              : aplique.costoFabricacion.toString(),
          activo: aplique.activo,
        ));

  Future<bool> onSubmit({required bool isUpdate}) async {
    if (state.nombre.trim().isEmpty) return false;
    final costo = double.tryParse(state.costoFabricacion);
    if (costo == null || costo < 0) return false;
    if (!_esMedidaValida(state.anchoCm) || !_esMedidaValida(state.altoCm)) {
      return false;
    }

    final apliqueLike = {
      'id': state.id,
      'nombre': state.nombre.trim(),
      'ancho_cm':
          state.anchoCm.isEmpty ? null : double.parse(state.anchoCm),
      'alto_cm': state.altoCm.isEmpty ? null : double.parse(state.altoCm),
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

  /// Vacío (sin medida) o número positivo.
  bool _esMedidaValida(String value) {
    if (value.isEmpty) return true;
    final medida = double.tryParse(value);
    return medida != null && medida > 0;
  }

  void onNombreChanged(String value) => emit(state.copyWith(nombre: value));
  void onAnchoChanged(String value) => emit(state.copyWith(anchoCm: value));
  void onAltoChanged(String value) => emit(state.copyWith(altoCm: value));
  void onCostoChanged(String value) =>
      emit(state.copyWith(costoFabricacion: value));
  void onActivoChanged(bool value) => emit(state.copyWith(activo: value));
}
