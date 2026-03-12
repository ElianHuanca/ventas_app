import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class SucursalState {
  final int id;
  final Sucursal? sucursal;
  final bool isLoading;

  SucursalState({
    required this.id,
    this.sucursal,
    this.isLoading = true,
  });

  SucursalState copyWith({
    int? id,
    Sucursal? sucursal,
    bool? isLoading,
  }) =>
      SucursalState(
        id: id ?? this.id,
        sucursal: sucursal ?? this.sucursal,
        isLoading: isLoading ?? this.isLoading,
      );
}

abstract class SucursalEvent {}

class SucursalLoadRequested extends SucursalEvent {}

class SucursalBloc extends Bloc<SucursalEvent, SucursalState> {
  final SucursalesRepository sucursalesRepository;

  SucursalBloc({required this.sucursalesRepository, required int id})
      : super(SucursalState(id: id)) {
    on<SucursalLoadRequested>(_onLoadRequested);
    add(SucursalLoadRequested());
  }

  Future<void> _onLoadRequested(
    SucursalLoadRequested event,
    Emitter<SucursalState> emit,
  ) async {
    try {
      if (state.id == 0) {
        emit(state.copyWith(sucursal: Sucursal.empty(), isLoading: false));
        return;
      }
      final sucursal = await sucursalesRepository.getSucursal(state.id);
      emit(state.copyWith(sucursal: sucursal));
    } catch (e) {
      print(e);
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
