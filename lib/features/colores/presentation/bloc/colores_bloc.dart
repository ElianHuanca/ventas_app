import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/apliques/domain/entities/color_item.dart';
import '../../domain/domain.dart';

class ColoresState {
  final bool isLoading;
  final List<ColorItem> colores;

  ColoresState({this.isLoading = false, this.colores = const []});

  ColoresState copyWith({bool? isLoading, List<ColorItem>? colores}) =>
      ColoresState(
        isLoading: isLoading ?? this.isLoading,
        colores: colores ?? this.colores,
      );
}

abstract class ColoresEvent {}

class ColoresLoadRequested extends ColoresEvent {}

class ColoresCreateRequested extends ColoresEvent {
  final ColorItem color;
  ColoresCreateRequested(this.color);
}

class ColoresUpdateRequested extends ColoresEvent {
  final ColorItem color;
  ColoresUpdateRequested(this.color);
}

class ColoresDeleteRequested extends ColoresEvent {
  final int id;
  ColoresDeleteRequested(this.id);
}

class ColoresBloc extends Bloc<ColoresEvent, ColoresState> {
  final ColoresRepository coloresRepository;

  ColoresBloc({required this.coloresRepository}) : super(ColoresState()) {
    on<ColoresLoadRequested>(_onLoadRequested);
    on<ColoresCreateRequested>(_onCreateRequested);
    on<ColoresUpdateRequested>(_onUpdateRequested);
    on<ColoresDeleteRequested>(_onDeleteRequested);
    add(ColoresLoadRequested());
  }

  Future<void> _onLoadRequested(
    ColoresLoadRequested event,
    Emitter<ColoresState> emit,
  ) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true));
    try {
      final colores = await coloresRepository.getColores();
      emit(state.copyWith(colores: colores));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onCreateRequested(
    ColoresCreateRequested event,
    Emitter<ColoresState> emit,
  ) async {
    emit(state.copyWith(colores: [event.color, ...state.colores]));
  }

  Future<void> _onUpdateRequested(
    ColoresUpdateRequested event,
    Emitter<ColoresState> emit,
  ) async {
    emit(state.copyWith(
        colores: state.colores
            .map((e) => e.id == event.color.id ? event.color : e)
            .toList()));
  }

  Future<void> _onDeleteRequested(
    ColoresDeleteRequested event,
    Emitter<ColoresState> emit,
  ) async {
    emit(state.copyWith(
        colores: state.colores.where((e) => e.id != event.id).toList()));
  }

  Future<bool> createColor(Map<String, dynamic> colorLike) async {
    try {
      final color = await coloresRepository.createColor(colorLike);
      add(ColoresCreateRequested(color));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateColor(Map<String, dynamic> colorLike) async {
    try {
      final color =
          await coloresRepository.updateColor(colorLike, colorLike['id']);
      add(ColoresUpdateRequested(color));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteColor(int id) async {
    try {
      final ok = await coloresRepository.deleteColor(id);
      if (!ok) return false;
      add(ColoresDeleteRequested(id));
      return true;
    } catch (_) {
      return false;
    }
  }
}
