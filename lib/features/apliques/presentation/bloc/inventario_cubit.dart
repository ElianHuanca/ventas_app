import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';

class InventarioState {
  final bool isLoading;

  /// La última carga falló (p. ej. sin conexión).
  final bool error;

  /// Todo el inventario con la regla aplicada: faltantes primero.
  final List<Reposicion> items;
  final bool soloFaltantes;

  /// Hasta qué día se miran las ventas (hoy): va en el mensaje.
  final DateTime fecha;

  const InventarioState({
    this.isLoading = false,
    this.error = false,
    this.items = const [],
    this.soloFaltantes = true,
    required this.fecha,
  });

  List<Reposicion> get faltantes => items.where((r) => r.faltante).toList();

  List<Reposicion> get visibles => soloFaltantes ? faltantes : items;

  /// La sucursal no vendió nada en la ventana: se estima con las otras.
  bool get estimada => items.isNotEmpty && items.first.estimada;

  int get totalAHacer => items.fold(0, (suma, r) => suma + r.hacer);

  InventarioState copyWith({
    bool? isLoading,
    bool? error,
    List<Reposicion>? items,
    bool? soloFaltantes,
    DateTime? fecha,
  }) =>
      InventarioState(
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
        items: items ?? this.items,
        soloFaltantes: soloFaltantes ?? this.soloFaltantes,
        fecha: fecha ?? this.fecha,
      );
}

class InventarioCubit extends Cubit<InventarioState> {
  final ApliquesRepository apliquesRepository;
  final int idsucursal;
  final DateTime Function() _hoy;

  InventarioCubit({
    required this.apliquesRepository,
    required this.idsucursal,
    DateTime Function()? hoy,
  })  : _hoy = hoy ?? DateTime.now,
        super(InventarioState(fecha: (hoy ?? DateTime.now)())) {
    unawaited(cargar());
  }

  /// Las ventas de las últimas [ReglaReposicion.semanasVentana] semanas,
  /// hoy incluido.
  Future<void> cargar() async {
    final hoy = _hoy();
    emit(state.copyWith(isLoading: true, error: false, fecha: hoy));
    try {
      final inventario = await apliquesRepository.getInventarioConVentas(
        idsucursal,
        desde: DateTime(hoy.year, hoy.month,
            hoy.day - (ReglaReposicion.semanasVentana * 7 - 1)),
        hasta: hoy,
      );
      emit(state.copyWith(
        isLoading: false,
        items: ReglaReposicion.aplicar(inventario),
      ));
    } catch (_) {
      // Sin datos no se puede decir qué falta: se avisa, no "no falta nada"
      emit(state.copyWith(isLoading: false, error: true, items: const []));
    }
  }

  void toggleSoloFaltantes() =>
      emit(state.copyWith(soloFaltantes: !state.soloFaltantes));
}
