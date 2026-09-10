import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/apliques/domain/entities/color_item.dart';
import '../../domain/domain.dart';

class TelaColoresState {
  final bool isLoading;
  final List<ColorItem> colores;

  TelaColoresState({this.isLoading = false, this.colores = const []});

  TelaColoresState copyWith({bool? isLoading, List<ColorItem>? colores}) =>
      TelaColoresState(
        isLoading: isLoading ?? this.isLoading,
        colores: colores ?? this.colores,
      );
}

class TelaColoresCubit extends Cubit<TelaColoresState> {
  final TelasRepository telasRepository;
  final int idtela;

  TelaColoresCubit({required this.telasRepository, required this.idtela})
      : super(TelaColoresState()) {
    load();
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    try {
      final colores = await telasRepository.getColoresTela(idtela);
      emit(state.copyWith(colores: colores));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> toggleColor(int idcolor, bool vinculado) async {
    try {
      await telasRepository.setColorTela(idtela, idcolor, vinculado);
      emit(state.copyWith(
        colores: state.colores
            .map((e) => e.id == idcolor
                ? ColorItem(
                    id: e.id, nombre: e.nombre, hex: e.hex, vinculado: vinculado)
                : e)
            .toList(),
      ));
    } catch (_) {}
  }
}
