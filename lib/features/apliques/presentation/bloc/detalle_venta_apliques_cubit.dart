import 'dart:async';

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
    unawaited(load());
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    try {
      final lineas =
          await ventasApliquesRepository.getDetalleVentasApliques(idventa);
      emit(state.copyWith(lineas: [...lineas]..sort(_porApliqueYCantidad)));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}

/// Como el inventario: por aplique (A→Z) y, dentro de cada uno, de la línea
/// con más unidades a la que menos; a igual cantidad, por nombre completo.
int _porApliqueYCantidad(DetalleVentaAplique a, DetalleVentaAplique b) {
  final porAplique = _aplique(a.nombre).compareTo(_aplique(b.nombre));
  if (porAplique != 0) return porAplique;
  final porCantidad = b.cantidad.compareTo(a.cantidad);
  if (porCantidad != 0) return porCantidad;
  final porNombre = a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
  if (porNombre != 0) return porNombre;
  return a.id.compareTo(b.id);
}

/// La línea se guarda como "Aplique (Color)" (venta_apliques_form_cubit);
/// una vieja sin color queda entera.
String _aplique(String nombre) {
  final abre = nombre.lastIndexOf(' (');
  final sinColor =
      abre > 0 && nombre.endsWith(')') ? nombre.substring(0, abre) : nombre;
  return sinColor.toLowerCase();
}
