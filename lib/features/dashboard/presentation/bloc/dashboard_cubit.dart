import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';

class DashboardState {
  final bool isLoading;

  /// La última carga falló (p. ej. sin conexión): no hay datos del período.
  final bool error;
  final List<TopProducto> topTelas;
  final List<TopProducto> topApliques;
  final bool verPorCantidad;
  final ResumenVentas? resumenTelas;
  final ResumenVentas? resumenApliques;
  final DateTime desde;
  final DateTime hasta;

  DashboardState({
    this.isLoading = false,
    this.error = false,
    this.topTelas = const [],
    this.topApliques = const [],
    this.verPorCantidad = false,
    this.resumenTelas,
    this.resumenApliques,
    required this.desde,
    required this.hasta,
  });

  /// Rankings en el orden elegido (las RPC los devuelven por monto).
  List<TopProducto> get telasOrdenadas => _ordenar(topTelas);
  List<TopProducto> get apliquesOrdenados => _ordenar(topApliques);

  List<TopProducto> _ordenar(List<TopProducto> lista) => verPorCantidad
      ? (List.of(lista)
        ..sort((a, b) => b.totalCantidad.compareTo(a.totalCantidad)))
      : lista;

  DashboardState copyWith({
    bool? isLoading,
    bool? error,
    List<TopProducto>? topTelas,
    List<TopProducto>? topApliques,
    bool? verPorCantidad,
    ResumenVentas? resumenTelas,
    ResumenVentas? resumenApliques,
    DateTime? desde,
    DateTime? hasta,
  }) =>
      DashboardState(
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
        topTelas: topTelas ?? this.topTelas,
        topApliques: topApliques ?? this.topApliques,
        verPorCantidad: verPorCantidad ?? this.verPorCantidad,
        resumenTelas: resumenTelas ?? this.resumenTelas,
        resumenApliques: resumenApliques ?? this.resumenApliques,
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

  /// Carga telas y apliques juntos: cambiar de pestaña no vuelve a consultar.
  Future<void> cargar() async {
    emit(state.copyWith(isLoading: true, error: false));
    try {
      final desde = state.desde;
      final hasta = state.hasta;
      final resultados = await Future.wait([
        repository.getTopProductos(desde: desde, hasta: hasta),
        repository.getTopApliques(desde: desde, hasta: hasta),
        repository.getResumenVentas(desde: desde, hasta: hasta),
        repository.getResumenVentasApliques(desde: desde, hasta: hasta),
      ]);

      emit(state.copyWith(
        topTelas: resultados[0] as List<TopProducto>,
        topApliques: resultados[1] as List<TopProducto>,
        resumenTelas: resultados[2] as ResumenVentas,
        resumenApliques: resultados[3] as ResumenVentas,
      ));
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
