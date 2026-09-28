import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class ProduccionesState {
  final bool isLoading;
  final List<ProduccionCabecera> producciones;

  ProduccionesState({this.isLoading = false, this.producciones = const []});

  ProduccionesState copyWith({
    bool? isLoading,
    List<ProduccionCabecera>? producciones,
  }) =>
      ProduccionesState(
        isLoading: isLoading ?? this.isLoading,
        producciones: producciones ?? this.producciones,
      );
}

abstract class ProduccionesEvent {}

class ProduccionesLoadRequested extends ProduccionesEvent {
  final int idsucursal;
  ProduccionesLoadRequested(this.idsucursal);
}

class ProduccionesBloc extends Bloc<ProduccionesEvent, ProduccionesState> {
  final ApliquesRepository apliquesRepository;
  final int idsucursal;

  ProduccionesBloc({required this.apliquesRepository, required this.idsucursal})
      : super(ProduccionesState()) {
    on<ProduccionesLoadRequested>(_onLoadRequested);
    add(ProduccionesLoadRequested(idsucursal));
  }

  Future<void> _onLoadRequested(
    ProduccionesLoadRequested event,
    Emitter<ProduccionesState> emit,
  ) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true));
    try {
      final producciones =
          await apliquesRepository.getProducciones(event.idsucursal);
      emit(state.copyWith(producciones: producciones));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
