import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class DetalleVentasState {
  final int idventa;
  final bool isLoading;
  final List<DetalleVenta> detalleVentas;

  DetalleVentasState({
    required this.idventa,
    this.isLoading = true,
    this.detalleVentas = const [],
  });

  DetalleVentasState copyWith({
    int? idventa,
    bool? isLoading,
    List<DetalleVenta>? detalleVentas,
  }) =>
      DetalleVentasState(
        idventa: idventa ?? this.idventa,
        isLoading: isLoading ?? this.isLoading,
        detalleVentas: detalleVentas ?? this.detalleVentas,
      );
}

abstract class DetalleVentasEvent {}

class DetalleVentasLoadRequested extends DetalleVentasEvent {}

class DetalleVentasCreateRequested extends DetalleVentasEvent {
  final List<DetalleVenta> newItems;
  DetalleVentasCreateRequested(this.newItems);
}

class DetalleVentasDeleteRequested extends DetalleVentasEvent {
  final int id;
  DetalleVentasDeleteRequested(this.id);
}

class DetalleVentasBloc extends Bloc<DetalleVentasEvent, DetalleVentasState> {
  final DetalleVentasRepository detalleVentasRepository;
  final Future<bool> Function(Map<String, dynamic>) updateVenta;

  DetalleVentasBloc({
    required this.detalleVentasRepository,
    required this.updateVenta,
    required int idventa,
  }) : super(DetalleVentasState(idventa: idventa)) {
    on<DetalleVentasLoadRequested>(_onLoadRequested);
    on<DetalleVentasCreateRequested>(_onCreateRequested);
    on<DetalleVentasDeleteRequested>(_onDeleteRequested);
    add(DetalleVentasLoadRequested());
  }

  Future<void> _onLoadRequested(
    DetalleVentasLoadRequested event,
    Emitter<DetalleVentasState> emit,
  ) async {
    try {
      final list =
          await detalleVentasRepository.getDetalleVenta(state.idventa);
      if (list.isEmpty) {
        emit(state.copyWith(isLoading: false));
        return;
      }
      emit(state.copyWith(detalleVentas: list));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onCreateRequested(
    DetalleVentasCreateRequested event,
    Emitter<DetalleVentasState> emit,
  ) async {
    emit(state.copyWith(
        detalleVentas: [...event.newItems, ...state.detalleVentas]));
  }

  Future<void> _onDeleteRequested(
    DetalleVentasDeleteRequested event,
    Emitter<DetalleVentasState> emit,
  ) async {
    emit(state.copyWith(
        detalleVentas:
            state.detalleVentas.where((d) => d.id != event.id).toList()));
  }

  Future<bool> createDetVenta(List<Map<String, dynamic>> detalleVentasLike) async {
    try {
      final response = await detalleVentasRepository.createDetalleVenta(
          detalleVentasLike, state.idventa);
      add(DetalleVentasCreateRequested(response));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteDetVenta(int id) async {
    try {
      final response = await detalleVentasRepository.deleteDetalleVenta(id);
      final ventaLike = {
        'total': -(response.total ?? 0),
        'ganancias': -(response.ganancias ?? 0),
      };
      add(DetalleVentasDeleteRequested(id));
      return await updateVenta(ventaLike);
    } catch (_) {
      return false;
    }
  }
}
