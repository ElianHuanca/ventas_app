import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/domain.dart';

class FotosState {
  final bool isLoading;
  final bool error;
  final bool subiendo;
  final String nombre;
  final List<Foto> fotos;

  const FotosState({
    this.isLoading = false,
    this.error = false,
    this.subiendo = false,
    this.nombre = '',
    this.fotos = const [],
  });

  FotosState copyWith({
    bool? isLoading,
    bool? error,
    bool? subiendo,
    String? nombre,
    List<Foto>? fotos,
  }) =>
      FotosState(
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
        subiendo: subiendo ?? this.subiendo,
        nombre: nombre ?? this.nombre,
        fotos: fotos ?? this.fotos,
      );
}

/// Fotos de una tela o un aplique: la primera (por orden de subida) es la
/// que la web muestra primero en la tarjeta.
class FotosCubit extends Cubit<FotosState> {
  final FotosRepository fotosRepository;
  final ProductoConFotos producto;
  final int id;

  FotosCubit({
    required this.fotosRepository,
    required this.producto,
    required this.id,
  }) : super(const FotosState()) {
    unawaited(cargar());
  }

  Future<void> cargar() async {
    emit(state.copyWith(isLoading: true, error: false));
    try {
      final (nombre, fotos) = await (
        fotosRepository.getNombre(producto, id),
        fotosRepository.getFotos(producto, id),
      ).wait;
      emit(state.copyWith(isLoading: false, nombre: nombre, fotos: fotos));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: true));
    }
  }

  /// false si no se pudo subir (sin conexión, archivo muy grande…).
  Future<bool> subir(FotoElegida foto) async {
    if (state.subiendo) return false;
    emit(state.copyWith(subiendo: true));
    try {
      final nueva = await fotosRepository.subirFoto(producto, id, foto);
      emit(state.copyWith(subiendo: false, fotos: [...state.fotos, nueva]));
      return true;
    } catch (_) {
      emit(state.copyWith(subiendo: false));
      return false;
    }
  }

  /// Baja lógica: deja de verse en la app y en la web.
  Future<bool> quitar(int idfoto) async {
    try {
      await fotosRepository.quitarFoto(producto, idfoto);
      emit(state.copyWith(
          fotos: state.fotos.where((f) => f.id != idfoto).toList()));
      return true;
    } catch (_) {
      return false;
    }
  }
}
