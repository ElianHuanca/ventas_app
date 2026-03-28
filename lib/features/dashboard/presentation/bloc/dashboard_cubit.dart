import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';

class DashboardState {
  final bool isLoading;
  final List<TopProducto> topProductos;
  final DateTime desde;
  final DateTime hasta;

  DashboardState({
    this.isLoading = false,
    this.topProductos = const [],
    required this.desde,
    required this.hasta,
  });

  DashboardState copyWith({
    bool? isLoading,
    List<TopProducto>? topProductos,
    DateTime? desde,
    DateTime? hasta,
  }) =>
      DashboardState(
        isLoading: isLoading ?? this.isLoading,
        topProductos: topProductos ?? this.topProductos,
        desde: desde ?? this.desde,
        hasta: hasta ?? this.hasta,
      );
}

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository repository;

  DashboardCubit({required this.repository})
      : super(DashboardState(
          desde: DateTime(DateTime.now().year, DateTime.now().month, 1),
          hasta: DateTime.now(),
        )) {
    cargar();
  }

  Future<void> cargar() async {
    emit(state.copyWith(isLoading: true));
    try {
      final lista = await repository.getTopProductos(
        desde: state.desde,
        hasta: state.hasta,
      );

      emit(state.copyWith(topProductos: lista));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> cambiarRango(DateTime desde, DateTime hasta) async {
    emit(state.copyWith(desde: desde, hasta: hasta));
    await cargar();
  }
}
