import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class DetalleVentaApliquesState {
  final bool isLoading;
  final List<DetalleVentaAplique> lineas;

  DetalleVentaApliquesState({
    this.isLoading = false,
    this.lineas = const [],
  });

  DetalleVentaApliquesState copyWith({
    bool? isLoading,
    List<DetalleVentaAplique>? lineas,
  }) =>
      DetalleVentaApliquesState(
        isLoading: isLoading ?? this.isLoading,
        lineas: lineas ?? this.lineas,
      );
}

class DetalleVentaApliquesCubit extends Cubit<DetalleVentaApliquesState> {
  final VentasApliquesRepository ventasApliquesRepository;
  final int idventa;

  DetalleVentaApliquesCubit({
    required this.ventasApliquesRepository,
    required this.idventa,
  }) : super(DetalleVentaApliquesState()) {
    load();
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    try {
      final lineas =
          await ventasApliquesRepository.getDetalleVentasApliques(idventa);
      emit(state.copyWith(lineas: lineas));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
