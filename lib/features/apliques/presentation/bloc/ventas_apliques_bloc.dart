import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class VentasApliquesState {
  final bool isLoading;
  final List<VentaAplique> ventas;

  VentasApliquesState({this.isLoading = false, this.ventas = const []});

  VentasApliquesState copyWith({
    bool? isLoading,
    List<VentaAplique>? ventas,
  }) =>
      VentasApliquesState(
        isLoading: isLoading ?? this.isLoading,
        ventas: ventas ?? this.ventas,
      );
}

abstract class VentasApliquesEvent {}

class VentasApliquesLoadRequested extends VentasApliquesEvent {
  final int idsucursal;
  VentasApliquesLoadRequested(this.idsucursal);
}

class VentasApliquesBloc extends Bloc<VentasApliquesEvent, VentasApliquesState> {
  final VentasApliquesRepository ventasApliquesRepository;
  final int idsucursal;

  VentasApliquesBloc({
    required this.ventasApliquesRepository,
    required this.idsucursal,
  }) : super(VentasApliquesState()) {
    on<VentasApliquesLoadRequested>(_onLoadRequested);
    add(VentasApliquesLoadRequested(idsucursal));
  }

  Future<void> _onLoadRequested(
    VentasApliquesLoadRequested event,
    Emitter<VentasApliquesState> emit,
  ) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true));
    try {
      final ventas =
          await ventasApliquesRepository.getVentasApliques(event.idsucursal);
      emit(state.copyWith(ventas: ventas));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
