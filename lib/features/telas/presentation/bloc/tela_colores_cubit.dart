import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/apliques/domain/entities/color_item.dart';
import '../../domain/domain.dart';

class TelaColoresState {
  final bool isLoading;
  final List<ColorItem> colores;
  final String nombreTela;

  TelaColoresState({
    this.isLoading = false,
    this.colores = const [],
    this.nombreTela = '',
  });

  TelaColoresState copyWith({
    bool? isLoading,
    List<ColorItem>? colores,
    String? nombreTela,
  }) =>
      TelaColoresState(
        isLoading: isLoading ?? this.isLoading,
        colores: colores ?? this.colores,
        nombreTela: nombreTela ?? this.nombreTela,
      );
}

class TelaColoresCubit extends Cubit<TelaColoresState> {
  final TelasRepository telasRepository;
  final int idtela;

  TelaColoresCubit({required this.telasRepository, required this.idtela})
      : super(TelaColoresState()) {
    unawaited(load());
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    try {
      final colores = await telasRepository.getColoresTela(idtela);
      final tela = await telasRepository.getTela(idtela);
      emit(state.copyWith(colores: colores, nombreTela: tela.nombre));
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
