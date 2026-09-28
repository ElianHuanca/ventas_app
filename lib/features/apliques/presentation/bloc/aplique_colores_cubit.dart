import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class ApliqueColoresState {
  final bool isLoading;
  final List<ColorItem> colores;
  final String nombreAplique;

  ApliqueColoresState({
    this.isLoading = false,
    this.colores = const [],
    this.nombreAplique = '',
  });

  ApliqueColoresState copyWith({
    bool? isLoading,
    List<ColorItem>? colores,
    String? nombreAplique,
  }) =>
      ApliqueColoresState(
        isLoading: isLoading ?? this.isLoading,
        colores: colores ?? this.colores,
        nombreAplique: nombreAplique ?? this.nombreAplique,
      );
}

class ApliqueColoresCubit extends Cubit<ApliqueColoresState> {
  final ApliquesRepository apliquesRepository;
  final int idaplique;

  ApliqueColoresCubit({required this.apliquesRepository, required this.idaplique})
      : super(ApliqueColoresState()) {
    load();
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    try {
      final colores = await apliquesRepository.getColoresAplique(idaplique);
      // Orden alfabético sin distinguir mayúsculas.
      final ordenados = List<ColorItem>.from(colores)
        ..sort((a, b) =>
            a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      final apliques =
          await apliquesRepository.getApliques(soloActivos: false);
      final nombre = apliques
              .where((a) => a.id == idaplique)
              .map((a) => a.nombre)
              .firstOrNull ??
          '';
      emit(state.copyWith(colores: ordenados, nombreAplique: nombre));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> toggleColor(int idcolor, bool vinculado) async {
    try {
      await apliquesRepository.setColorAplique(idaplique, idcolor, vinculado);
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
