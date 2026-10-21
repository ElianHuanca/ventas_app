import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class VentaState {
  final int id;
  final Venta? venta;
  final bool isLoading;

  VentaState({
    required this.id,
    this.venta,
    this.isLoading = true,
  });

  VentaState copyWith({
    int? id,
    Venta? venta,
    bool? isLoading,
  }) =>
      VentaState(
        id: id ?? this.id,
        venta: venta ?? this.venta,
        isLoading: isLoading ?? this.isLoading,
      );
}

abstract class VentaEvent {}

class VentaLoadRequested extends VentaEvent {}

class VentaUpdateRequested extends VentaEvent {
  final Venta venta;
  VentaUpdateRequested(this.venta);
}

class VentaBloc extends Bloc<VentaEvent, VentaState> {
  final VentasRepository ventasRepository;

  VentaBloc({required this.ventasRepository, required int id})
      : super(VentaState(id: id)) {
    on<VentaLoadRequested>(_onLoadRequested);
    on<VentaUpdateRequested>(_onUpdateRequested);
    add(VentaLoadRequested());
  }

  Future<void> _onLoadRequested(
    VentaLoadRequested event,
    Emitter<VentaState> emit,
  ) async {
    try {
      final venta = await ventasRepository.getVenta(state.id);
      emit(state.copyWith(venta: venta));
    } catch (e) {
      debugPrint('Error al obtener venta: $e');
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onUpdateRequested(
    VentaUpdateRequested event,
    Emitter<VentaState> emit,
  ) async {
    emit(state.copyWith(venta: event.venta));
  }

  /// Muestra la venta que devolvió la base (al borrar una línea, con los
  /// totales ya descontados). Sin venta (la línea ya no estaba) la vuelve a
  /// leer: puede haberla cambiado otro dispositivo.
  void mostrarVenta(Venta? venta) =>
      add(venta == null ? VentaLoadRequested() : VentaUpdateRequested(venta));
}
