import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class SucursalesState {
  final bool isLoading;
  final List<Sucursal> sucursales;

  SucursalesState({this.isLoading = false, this.sucursales = const []});

  SucursalesState copyWith({bool? isLoading, List<Sucursal>? sucursales}) {
    return SucursalesState(
      isLoading: isLoading ?? this.isLoading,
      sucursales: sucursales ?? this.sucursales,
    );
  }
}

abstract class SucursalesEvent {}

class SucursalesLoadRequested extends SucursalesEvent {}

class SucursalesCreateRequested extends SucursalesEvent {
  final Sucursal sucursal;
  SucursalesCreateRequested(this.sucursal);
}

class SucursalesUpdateRequested extends SucursalesEvent {
  final Sucursal sucursal;
  SucursalesUpdateRequested(this.sucursal);
}

class SucursalesDeleteRequested extends SucursalesEvent {
  final int id;
  SucursalesDeleteRequested(this.id);
}

class SucursalesBloc extends Bloc<SucursalesEvent, SucursalesState> {
  final SucursalesRepository sucursalesRepository;

  SucursalesBloc({required this.sucursalesRepository})
      : super(SucursalesState()) {
    on<SucursalesLoadRequested>(_onLoadRequested);
    on<SucursalesCreateRequested>(_onCreateRequested);
    on<SucursalesUpdateRequested>(_onUpdateRequested);
    on<SucursalesDeleteRequested>(_onDeleteRequested);
    add(SucursalesLoadRequested());
  }

  Future<void> _onLoadRequested(
    SucursalesLoadRequested event,
    Emitter<SucursalesState> emit,
  ) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true));
    try {
      final sucursales = await sucursalesRepository.getSucursales();
      emit(state.copyWith(sucursales: sucursales));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onCreateRequested(
    SucursalesCreateRequested event,
    Emitter<SucursalesState> emit,
  ) async {
    emit(state.copyWith(sucursales: [...state.sucursales, event.sucursal]));
  }

  Future<void> _onUpdateRequested(
    SucursalesUpdateRequested event,
    Emitter<SucursalesState> emit,
  ) async {
    emit(state.copyWith(
        sucursales: state.sucursales
            .map((e) => e.id == event.sucursal.id ? event.sucursal : e)
            .toList()));
  }

  Future<void> _onDeleteRequested(
    SucursalesDeleteRequested event,
    Emitter<SucursalesState> emit,
  ) async {
    emit(state.copyWith(
        sucursales:
            state.sucursales.where((e) => e.id != event.id).toList()));
  }

  Future<bool> createSucursal(Map<String, dynamic> sucursalLike) async {
    try {
      final sucursal = await sucursalesRepository.createSucursal(sucursalLike);
      add(SucursalesCreateRequested(sucursal));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateSucursal(Map<String, dynamic> sucursalLike) async {
    try {
      final sucursal = await sucursalesRepository.updateSucursal(
          sucursalLike, sucursalLike['id']);
      add(SucursalesUpdateRequested(sucursal));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteSucursal(int id) async {
    try {
      final ok = await sucursalesRepository.deleteSucursal(id);
      if (!ok) return false;
      add(SucursalesDeleteRequested(id));
      return true;
    } catch (_) {
      return false;
    }
  }
}
