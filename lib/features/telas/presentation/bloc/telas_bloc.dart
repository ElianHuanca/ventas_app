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

class TelasBloc extends Bloc<TelasEvent, TelasState> {
  final TelasRepository telasRepository;

  /// Si se indica una sucursal, se cargan solo las telas disponibles en ella
  /// (ver getTelasPorSucursal; sin vínculos configurados = catálogo completo).
  final int? idsucursal;

  TelasBloc({required this.telasRepository, this.idsucursal})
      : super(TelasState()) {
    on<TelasLoadRequested>(_onLoadRequested);
    on<TelasCreateRequested>(_onCreateRequested);
    on<TelasUpdateRequested>(_onUpdateRequested);
    add(TelasLoadRequested());
  }

  Future<void> _onLoadRequested(
    TelasLoadRequested event,
    Emitter<TelasState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      final telas = idsucursal == null
          ? await telasRepository.getTelas(soloActivos: false)
          : await telasRepository.getTelasPorSucursal(idsucursal!);
      emit(state.copyWith(telas: telas));
    } catch (_) {
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

  Future<bool> createTela(Map<String, dynamic> telaLike) async {
    try {
      final tela = await telasRepository.createTela(telaLike);
      add(TelasCreateRequested(tela));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateTela(Map<String, dynamic> telaLike) async {
    try {
      final tela =
          await telasRepository.updateTela(telaLike, telaLike['id'] as int);
      add(TelasUpdateRequested(tela));
      return true;
    } catch (_) {
      return false;
    }
  }

}
