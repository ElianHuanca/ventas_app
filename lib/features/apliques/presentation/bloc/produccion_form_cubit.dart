import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class ProduccionFormState {
  final bool isLoading;
  final bool isSubmitting;
  final List<Aplique> apliques;
  final List<ColorItem> colores;
  final List<Produccion> producciones;
  final int idsucursal;
  final int idapliques;
  final int idcolor;
  final String cantidad;

  ProduccionFormState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.apliques = const [],
    this.colores = const [],
    this.producciones = const [],
    this.idsucursal = 0,
    this.idapliques = 0,
    this.idcolor = 0,
    this.cantidad = '',
  });

  ProduccionFormState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<Aplique>? apliques,
    List<ColorItem>? colores,
    List<Produccion>? producciones,
    int? idsucursal,
    int? idapliques,
    int? idcolor,
    String? cantidad,
  }) =>
      ProduccionFormState(
        isLoading: isLoading ?? this.isLoading,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        apliques: apliques ?? this.apliques,
        colores: colores ?? this.colores,
        producciones: producciones ?? this.producciones,
        idsucursal: idsucursal ?? this.idsucursal,
        idapliques: idapliques ?? this.idapliques,
        idcolor: idcolor ?? this.idcolor,
        cantidad: cantidad ?? this.cantidad,
      );
}

class ProduccionFormCubit extends Cubit<ProduccionFormState> {
  final ApliquesRepository apliquesRepository;

  ProduccionFormCubit({required this.apliquesRepository})
      : super(ProduccionFormState()) {
    load();
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    try {
      final apliques = await apliquesRepository.getApliques();
      final producciones = await apliquesRepository.getProducciones();
      emit(state.copyWith(
        apliques: apliques,
        producciones: producciones,
      ));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  void onSucursalChanged(int value) =>
      emit(state.copyWith(idsucursal: value));

  /// Solo se ofrecen los colores vinculados al aplique (aplique_colores).
  Future<void> onApliqueChanged(Aplique? value) async {
    final id = value?.id ?? 0;
    emit(state.copyWith(idapliques: id, idcolor: 0, colores: []));
    if (id == 0) return;
    try {
      final colores = await apliquesRepository.getColoresAplique(id);
      emit(state.copyWith(
          colores: colores.where((e) => e.vinculado).toList()));
    } catch (_) {}
  }
  void onColorChanged(ColorItem? value) =>
      emit(state.copyWith(idcolor: value?.id ?? 0));
  void onCantidadChanged(String value) =>
      emit(state.copyWith(cantidad: value));

  /// Devuelve null si se registró, o el mensaje de error a mostrar.
  Future<String?> registrar() async {
    if (state.isSubmitting) return null;
    if (state.idsucursal == 0) return 'Seleccione una sucursal';
    if (state.idapliques == 0) return 'Seleccione un aplique';
    if (state.idcolor == 0) return 'Seleccione un color';
    final cantidad = double.tryParse(state.cantidad);
    if (cantidad == null || cantidad <= 0) {
      return 'Ingrese una cantidad válida mayor a 0';
    }

    emit(state.copyWith(isSubmitting: true));
    try {
      await apliquesRepository.createProduccion(
        sucursalId: state.idsucursal,
        apliqueId: state.idapliques,
        colorId: state.idcolor,
        cantidad: cantidad,
      );
      final producciones = await apliquesRepository.getProducciones();
      emit(state.copyWith(producciones: producciones, cantidad: ''));
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      emit(state.copyWith(isSubmitting: false));
    }
  }
}
