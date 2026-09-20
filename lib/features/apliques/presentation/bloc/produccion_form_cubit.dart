import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class ProduccionFormState {
  final bool isLoading;
  final bool isSubmitting;
  final List<Aplique> apliques;
  final List<StockAplique> stock;
  final List<ColorItem> colores;
  final int idsucursal;
  final int idapliques;
  final int idcolor;
  final String cantidad;

  ProduccionFormState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.apliques = const [],
    this.stock = const [],
    this.colores = const [],
    this.idsucursal = 0,
    this.idapliques = 0,
    this.idcolor = 0,
    this.cantidad = '',
  });

  /// Stock actual del aplique+color seleccionados en la sucursal elegida.
  /// Sirve de guía al ingresar la cantidad a fabricar.
  double get stockActual {
    for (final e in stock) {
      if (e.apliqueId == idapliques && e.colorId == idcolor) return e.stock;
    }
    return 0;
  }

  ProduccionFormState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<Aplique>? apliques,
    List<StockAplique>? stock,
    List<ColorItem>? colores,
    int? idsucursal,
    int? idapliques,
    int? idcolor,
    String? cantidad,
  }) =>
      ProduccionFormState(
        isLoading: isLoading ?? this.isLoading,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        apliques: apliques ?? this.apliques,
        stock: stock ?? this.stock,
        colores: colores ?? this.colores,
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
      emit(state.copyWith(apliques: apliques));
    } catch (_) {
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> onSucursalChanged(int value) async {
    emit(state.copyWith(
      idsucursal: value,
      idapliques: 0,
      idcolor: 0,
      colores: [],
      stock: [],
    ));
    if (value == 0) return;
    try {
      final stock = await apliquesRepository.getStock(value);
      emit(state.copyWith(stock: stock));
    } catch (_) {}
  }

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

  /// Registra la producción y refresca el stock. El propio datasource suma
  /// la cantidad a la producción del mismo aplique+color+sucursal si ya hay
  /// una registrada hoy, en vez de crear una fila duplicada por el día.
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
      final stock = await apliquesRepository.getStock(state.idsucursal);
      emit(state.copyWith(stock: stock, cantidad: ''));
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      emit(state.copyWith(isSubmitting: false));
    }
  }
}
