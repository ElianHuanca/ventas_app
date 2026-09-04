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

class ApliquesBloc extends Bloc<ApliquesEvent, ApliquesState> {
  final ApliquesRepository apliquesRepository;
  final int idsucursal;

  ApliquesBloc({
    required this.apliquesRepository,
    required this.idsucursal,
  }) : super(ApliquesState()) {
    on<ApliquesLoadRequested>(_onLoadRequested);
    add(ApliquesLoadRequested());
  }

  Future<void> _onLoadRequested(
    ApliquesLoadRequested event,
    Emitter<ApliquesState> emit,
  ) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true));
    try {
      final apliques = await apliquesRepository.getApliques();
      final stock = await apliquesRepository.getStock(idsucursal);
      emit(state.copyWith(apliques: apliques, stock: stock));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
