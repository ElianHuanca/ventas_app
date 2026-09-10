import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class SucursalDisponibilidadState {
  final bool isLoading;
  final List<TelaSucursal> telas;

  SucursalDisponibilidadState({
    this.isLoading = false,
    this.telas = const [],
  });

  SucursalDisponibilidadState copyWith({
    bool? isLoading,
    List<TelaSucursal>? telas,
  }) =>
      SucursalDisponibilidadState(
        isLoading: isLoading ?? this.isLoading,
        telas: telas ?? this.telas,
      );
}

class SucursalDisponibilidadCubit extends Cubit<SucursalDisponibilidadState> {
  final SucursalesRepository sucursalesRepository;
  final int idsucursal;

  SucursalDisponibilidadCubit({
    required this.sucursalesRepository,
    required this.idsucursal,
  }) : super(SucursalDisponibilidadState()) {
    load();
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    try {
      final telas = await sucursalesRepository.getTelasSucursal(idsucursal);
      emit(state.copyWith(telas: telas));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> toggleTela(int idtela, bool disponible) async {
    try {
      await sucursalesRepository.setTelaSucursal(idtela, idsucursal, disponible);
      emit(state.copyWith(
        telas: state.telas
            .map((e) =>
                e.idtela == idtela ? e.copyWith(disponible: disponible) : e)
            .toList(),
      ));
    } catch (_) {}
  }
}
