import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class ProduccionesHistorialState {
  final bool isLoading;
  final List<Produccion> producciones;

  ProduccionesHistorialState({
    this.isLoading = false,
    this.producciones = const [],
  });

  ProduccionesHistorialState copyWith({
    bool? isLoading,
    List<Produccion>? producciones,
  }) =>
      ProduccionesHistorialState(
        isLoading: isLoading ?? this.isLoading,
        producciones: producciones ?? this.producciones,
      );
}

class ProduccionesHistorialCubit extends Cubit<ProduccionesHistorialState> {
  final ApliquesRepository apliquesRepository;

  ProduccionesHistorialCubit({required this.apliquesRepository})
      : super(ProduccionesHistorialState()) {
    load();
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    try {
      final producciones = await apliquesRepository.getProducciones();
      emit(state.copyWith(producciones: producciones));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
