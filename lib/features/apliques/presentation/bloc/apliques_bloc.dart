import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class ApliquesState {
  final bool isLoading;
  final List<Aplique> apliques;
  final List<StockAplique> stock;

  ApliquesState({
    this.isLoading = false,
    this.apliques = const [],
    this.stock = const [],
  });

  ApliquesState copyWith({
    bool? isLoading,
    List<Aplique>? apliques,
    List<StockAplique>? stock,
  }) =>
      ApliquesState(
        isLoading: isLoading ?? this.isLoading,
        apliques: apliques ?? this.apliques,
        stock: stock ?? this.stock,
      );
}

abstract class ApliquesEvent {}

class ApliquesLoadRequested extends ApliquesEvent {}

class ApliquesCreateRequested extends ApliquesEvent {
  final Aplique aplique;
  ApliquesCreateRequested(this.aplique);
}

class ApliquesUpdateRequested extends ApliquesEvent {
  final Aplique aplique;
  ApliquesUpdateRequested(this.aplique);
}

class ApliquesBloc extends Bloc<ApliquesEvent, ApliquesState> {
  final ApliquesRepository apliquesRepository;

  /// Si es null, el bloc se usa para GESTIÓN (lista todos los apliques,
  /// incluidos los inactivos, y no carga stock). Con sucursal, es el flujo
  /// de venta: solo activos + stock de esa sucursal.
  final int? idsucursal;

  ApliquesBloc({
    required this.apliquesRepository,
    this.idsucursal,
  }) : super(ApliquesState()) {
    on<ApliquesLoadRequested>(_onLoadRequested);
    on<ApliquesCreateRequested>(_onCreateRequested);
    on<ApliquesUpdateRequested>(_onUpdateRequested);
    add(ApliquesLoadRequested());
  }

  Future<void> _onLoadRequested(
    ApliquesLoadRequested event,
    Emitter<ApliquesState> emit,
  ) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true));
    try {
      final apliques = await apliquesRepository.getApliques(
          soloActivos: idsucursal != null);
      final stock = idsucursal == null
          ? <StockAplique>[]
          : await apliquesRepository.getStock(idsucursal!);
      emit(state.copyWith(apliques: apliques, stock: stock));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onCreateRequested(
    ApliquesCreateRequested event,
    Emitter<ApliquesState> emit,
  ) async {
    emit(state.copyWith(apliques: [event.aplique, ...state.apliques]));
  }

  Future<void> _onUpdateRequested(
    ApliquesUpdateRequested event,
    Emitter<ApliquesState> emit,
  ) async {
    emit(state.copyWith(
        apliques: state.apliques
            .map((e) => e.id == event.aplique.id ? event.aplique : e)
            .toList()));
  }

  Future<bool> createAplique(Map<String, dynamic> apliqueLike) async {
    try {
      final aplique = await apliquesRepository.createAplique(apliqueLike);
      add(ApliquesCreateRequested(aplique));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateAplique(Map<String, dynamic> apliqueLike) async {
    try {
      final aplique = await apliquesRepository.updateAplique(
          apliqueLike, apliqueLike['id'] as int);
      add(ApliquesUpdateRequested(aplique));
      return true;
    } catch (_) {
      return false;
    }
  }
}
