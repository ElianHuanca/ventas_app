import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class TelasState {
  final bool isLoading;
  final List<Tela> telas;

  TelasState({this.isLoading = false, this.telas = const []});

  TelasState copyWith({bool? isLoading, List<Tela>? telas}) {
    return TelasState(
      isLoading: isLoading ?? this.isLoading,
      telas: telas ?? this.telas,
    );
  }
}

abstract class TelasEvent {}

class TelasLoadRequested extends TelasEvent {}

class TelasCreateRequested extends TelasEvent {
  final Tela tela;
  TelasCreateRequested(this.tela);
}

class TelasUpdateRequested extends TelasEvent {
  final Tela tela;
  TelasUpdateRequested(this.tela);
}

class TelasDeleteRequested extends TelasEvent {
  final int id;
  TelasDeleteRequested(this.id);
}

class TelasBloc extends Bloc<TelasEvent, TelasState> {
  final TelasRepository telasRepository;

  TelasBloc({required this.telasRepository}) : super(TelasState()) {
    on<TelasLoadRequested>(_onLoadRequested);
    on<TelasCreateRequested>(_onCreateRequested);
    on<TelasUpdateRequested>(_onUpdateRequested);
    on<TelasDeleteRequested>(_onDeleteRequested);
    add(TelasLoadRequested());
  }

  Future<void> _onLoadRequested(
    TelasLoadRequested event,
    Emitter<TelasState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final telas = await telasRepository.getTelas();
      emit(state.copyWith(telas: telas));
    } catch (e) {
      print("Error al obtener telas: $e");
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onCreateRequested(
    TelasCreateRequested event,
    Emitter<TelasState> emit,
  ) async {
    emit(state.copyWith(telas: [event.tela, ...state.telas]));
  }

  Future<void> _onUpdateRequested(
    TelasUpdateRequested event,
    Emitter<TelasState> emit,
  ) async {
    emit(state.copyWith(
        telas: state.telas
            .map((e) => e.id == event.tela.id ? event.tela : e)
            .toList()));
  }

  Future<void> _onDeleteRequested(
    TelasDeleteRequested event,
    Emitter<TelasState> emit,
  ) async {
    emit(state.copyWith(
        telas: state.telas.where((e) => e.id != event.id).toList()));
  }

  Future<bool> createTela(Map<String, dynamic> telaLike) async {
    try {
      final tela = await telasRepository.createTela(telaLike);
      add(TelasCreateRequested(tela));
      return true;
    } catch (e) {
      print("Error creando tela: $e");
      return false;
    }
  }

  Future<bool> updateTela(Map<String, dynamic> telaLike) async {
    try {
      final tela =
          await telasRepository.updateTela(telaLike, telaLike['id']);
      add(TelasUpdateRequested(tela));
      return true;
    } catch (e) {
      print("Error actualizando tela: $e");
      return false;
    }
  }

  Future<bool> deleteTela(int id) async {
    try {
      final ok = await telasRepository.deleteTela(id);
      if (!ok) return false;
      add(TelasDeleteRequested(id));
      return true;
    } catch (e) {
      print("Error eliminando tela: $e");
      return false;
    }
  }
}
