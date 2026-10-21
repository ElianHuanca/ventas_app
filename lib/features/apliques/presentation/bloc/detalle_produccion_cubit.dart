import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class DetalleProduccionState {
  final bool isLoading;
  final List<Produccion> lineas;

  DetalleProduccionState({
    this.isLoading = false,
    this.lineas = const [],
  });

  DetalleProduccionState copyWith({
    bool? isLoading,
    List<Produccion>? lineas,
  }) =>
      DetalleProduccionState(
        isLoading: isLoading ?? this.isLoading,
        lineas: lineas ?? this.lineas,
      );
}

class DetalleProduccionCubit extends Cubit<DetalleProduccionState> {
  final ApliquesRepository apliquesRepository;
  final int idproduccion;

  DetalleProduccionCubit({
    required this.apliquesRepository,
    required this.idproduccion,
  }) : super(DetalleProduccionState()) {
    unawaited(load());
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    try {
      final lineas =
          await apliquesRepository.getDetalleProduccion(idproduccion);
      emit(state.copyWith(lineas: lineas));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
