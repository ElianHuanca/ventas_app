import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';

/// Línea de negocio de un dashboard: cada una tiene su submenú y su ruta.
enum LineaDashboard { telas, apliques }

class DashboardState {
  final bool isLoading;

  /// La última carga falló (p. ej. sin conexión): no hay datos del período.
  final bool error;

  /// Ranking en el orden de la RPC (por monto).
  final List<TopProducto> top;
  final bool verPorCantidad;
  final ResumenVentas? resumen;
  final DateTime desde;
  final DateTime hasta;

  DashboardState({
    this.isLoading = false,
    this.error = false,
    this.top = const [],
    this.verPorCantidad = false,
    this.resumen,
    required this.desde,
    required this.hasta,
  });

  /// Ranking en el orden elegido (las RPC lo devuelven por monto).
  List<TopProducto> get ordenados => verPorCantidad
      ? (List.of(top)
        ..sort((a, b) => b.totalCantidad.compareTo(a.totalCantidad)))
      : top;

  DashboardState copyWith({
    bool? isLoading,
    bool? error,
    List<TopProducto>? top,
    bool? verPorCantidad,
    ResumenVentas? resumen,
    DateTime? desde,
    DateTime? hasta,
  }) =>
      DashboardState(
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
        top: top ?? this.top,
        verPorCantidad: verPorCantidad ?? this.verPorCantidad,
        resumen: resumen ?? this.resumen,
        desde: desde ?? this.desde,
        hasta: hasta ?? this.hasta,
      );
}

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository repository;
  final LineaDashboard linea;

  DashboardCubit({required this.repository, required this.linea})
      : super(DashboardState(
          desde: DateTime(DateTime.now().year, DateTime.now().month, 1),
          hasta: DateTime.now(),
        )) {
    cargar();
  }

  /// Carga el ranking y el resumen de [linea] (sus dos RPC, juntas).
  Future<void> cargar() async {
    emit(state.copyWith(isLoading: true, error: false));
    try {
      final desde = state.desde;
      final hasta = state.hasta;
      final (top, resumen) = await switch (linea) {
        LineaDashboard.telas => (
            repository.getTopProductos(desde: desde, hasta: hasta),
            repository.getResumenVentas(desde: desde, hasta: hasta),
          ).wait,
        LineaDashboard.apliques => (
            repository.getTopApliques(desde: desde, hasta: hasta),
            repository.getResumenVentasApliques(desde: desde, hasta: hasta),
          ).wait,
      };

      emit(state.copyWith(top: top, resumen: resumen));
    } catch (_) {
      // Sin los datos del período: se avisa en vez de mostrar "Sin ventas"
      // (ni los del período anterior bajo las fechas nuevas)
      emit(DashboardState(
        error: true,
        verPorCantidad: state.verPorCantidad,
        desde: state.desde,
        hasta: state.hasta,
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
