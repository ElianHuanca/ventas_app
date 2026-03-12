import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class TelaState {
  final int id;
  final Tela? tela;
  final bool isLoading;

  TelaState({
    required this.id,
    this.tela,
    this.isLoading = true,
  });

  TelaState copyWith({
    int? id,
    Tela? tela,
    bool? isLoading,
  }) =>
      TelaState(
        id: id ?? this.id,
        tela: tela ?? this.tela,
        isLoading: isLoading ?? this.isLoading,
      );
}

abstract class TelaEvent {}

class TelaLoadRequested extends TelaEvent {}

class TelaBloc extends Bloc<TelaEvent, TelaState> {
  final TelasRepository telasRepository;

  TelaBloc({required this.telasRepository, required int id})
      : super(TelaState(id: id)) {
    on<TelaLoadRequested>(_onLoadRequested);
    add(TelaLoadRequested());
  }

  Future<void> _onLoadRequested(
    TelaLoadRequested event,
    Emitter<TelaState> emit,
  ) async {
    try {
      if (state.id == 0) {
        emit(state.copyWith(tela: Tela.empty(), isLoading: false));
        return;
      }
      final tela = await telasRepository.getTela(state.id);
      emit(state.copyWith(tela: tela));
    } catch (e) {
      print("Error cargando tela: $e");
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
