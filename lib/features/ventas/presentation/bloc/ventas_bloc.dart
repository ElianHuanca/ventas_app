import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class VentasState {
  final bool isLoading;
  final List<Venta> ventas;

  VentasState({this.isLoading = false, this.ventas = const []});

  VentasState copyWith({bool? isLoading, List<Venta>? ventas}) =>
      VentasState(
        isLoading: isLoading ?? this.isLoading,
        ventas: ventas ?? this.ventas,
      );
}

abstract class VentasEvent {}

class VentasLoadRequested extends VentasEvent {
  final int idsucursal;
  VentasLoadRequested(this.idsucursal);
}

class VentasBloc extends Bloc<VentasEvent, VentasState> {
  final VentasRepository ventasRepository;
  final int idsucursal;

  VentasBloc({required this.ventasRepository, required this.idsucursal})
      : super(VentasState()) {
    on<VentasLoadRequested>(_onLoadRequested);
    add(VentasLoadRequested(idsucursal));
  }

  Future<void> _onLoadRequested(
    VentasLoadRequested event,
    Emitter<VentasState> emit,
  ) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true));
    try {
      final ventas = await ventasRepository.getVentas(event.idsucursal);
      if (ventas.isEmpty) {
        final venta =
            await ventasRepository.createVentaAhora(event.idsucursal);
        emit(state.copyWith(ventas: [venta]));
        return;
      }
      final now = DateTime.now();
      if (ventas[0].fecha.isBefore(DateTime(now.year, now.month, now.day))) {
        final venta =
            await ventasRepository.createVentaAhora(event.idsucursal);
        ventas.insert(0, venta);
      }
      emit(state.copyWith(ventas: ventas));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
