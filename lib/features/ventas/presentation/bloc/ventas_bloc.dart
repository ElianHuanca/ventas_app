import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class VentasState {
  final bool isLoading;
  final List<Venta> ventas;

  VentasState({this.isLoading = false, this.ventas = const []});

  VentasState copyWith({bool? isLoading, List<Venta>? ventas}) => VentasState(
        isLoading: isLoading ?? this.isLoading,
        ventas: ventas ?? this.ventas,
      );
}

abstract class VentasEvent {}

class VentasLoadRequested extends VentasEvent {
  final int idsucursal;
  VentasLoadRequested(this.idsucursal);
}

class _VentasVentaAdded extends VentasEvent {
  final Venta venta;
  _VentasVentaAdded(this.venta);
}

class VentasBloc extends Bloc<VentasEvent, VentasState> {
  final VentasRepository ventasRepository;
  final int idsucursal;

  VentasBloc({required this.ventasRepository, required this.idsucursal})
      : super(VentasState()) {
    on<VentasLoadRequested>(_onLoadRequested);
    on<_VentasVentaAdded>((event, emit) =>
        emit(state.copyWith(ventas: [event.venta, ...state.ventas])));
    add(VentasLoadRequested(idsucursal));
  }

  Future<Venta?> createVenta(DateTime fecha) async {
    try {
      final venta = await ventasRepository.createVenta(idsucursal, fecha);
      add(_VentasVentaAdded(venta));
      return venta;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteVentaIfEmpty(int id) async {
    try {
      final venta = await ventasRepository.getVenta(id);
      if (venta.total == 0) {
        await ventasRepository.deleteVenta(id);
      }
    } catch (_) {}
  }

  Future<void> _onLoadRequested(
    VentasLoadRequested event,
    Emitter<VentasState> emit,
  ) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true));
    try {
      final ventas = await ventasRepository.getVentas(event.idsucursal);
      emit(state.copyWith(ventas: ventas));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
