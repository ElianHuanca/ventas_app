import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';

class DashboardState {
  final bool isLoading;
  final List<TopProducto> topProductos;
  final List<TopProducto> topProductosPorCantidad;
  final bool verPorCantidad;
  final ResumenVentas? resumen;
  final DateTime desde;
  final DateTime hasta;

  DashboardState({
    this.isLoading = false,
    this.topProductos = const [],
    this.topProductosPorCantidad = const [],
    this.verPorCantidad = false,
    this.resumen,
    required this.desde,
    required this.hasta,
  });

  DashboardState copyWith({
    bool? isLoading,
    List<TopProducto>? topProductos,
    List<TopProducto>? topProductosPorCantidad,
    bool? verPorCantidad,
    ResumenVentas? resumen,
    DateTime? desde,
    DateTime? hasta,
  }) =>
      DashboardState(
        isLoading: isLoading ?? this.isLoading,
        topProductos: topProductos ?? this.topProductos,
        topProductosPorCantidad:
            topProductosPorCantidad ?? this.topProductosPorCantidad,
        verPorCantidad: verPorCantidad ?? this.verPorCantidad,
        resumen: resumen ?? this.resumen,
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
      final resultados = await Future.wait([
        repository.getTopProductos(desde: state.desde, hasta: state.hasta),
        repository.getResumenVentas(desde: state.desde, hasta: state.hasta),
      ]);

      final lista = resultados[0] as List<TopProducto>;
      final resumen = resultados[1] as ResumenVentas;

      final porCantidad = List<TopProducto>.from(lista)
        ..sort((a, b) => b.totalCantidad.compareTo(a.totalCantidad));

      emit(state.copyWith(
        topProductos: lista,
        topProductosPorCantidad: porCantidad,
        resumen: resumen,
      ));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  void toggleVista() {
    emit(state.copyWith(verPorCantidad: !state.verPorCantidad));
  }

  Future<void> cambiarRango(DateTime desde, DateTime hasta) async {
    emit(state.copyWith(desde: desde, hasta: hasta));
    await cargar();
  }
}
