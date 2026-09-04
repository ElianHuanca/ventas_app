import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class VentaApliquesFormState {
  final int idapliques;
  final int idcolor;
  final String nombre;
  final String nombreColor;
  final String hex;
  final double stockDisponible;
  final double costoFabricacion;
  final String cantidad;
  final String precio;
  final List<Map<String, dynamic>> detalles;
  final double total;
  final String descuento;
  final double ganancias;

  VentaApliquesFormState({
    this.idapliques = 0,
    this.idcolor = 0,
    this.nombre = '',
    this.nombreColor = '',
    this.hex = '',
    this.stockDisponible = 0,
    this.costoFabricacion = 0,
    this.cantidad = '',
    this.precio = '',
    this.detalles = const [],
    this.total = 0,
    this.descuento = '',
    this.ganancias = 0,
  });

  VentaApliquesFormState copyWith({
    int? idapliques,
    int? idcolor,
    String? nombre,
    String? nombreColor,
    String? hex,
    double? stockDisponible,
    double? costoFabricacion,
    String? cantidad,
    String? precio,
    List<Map<String, dynamic>>? detalles,
    double? total,
    String? descuento,
    double? ganancias,
  }) =>
      VentaApliquesFormState(
        idapliques: idapliques ?? this.idapliques,
        idcolor: idcolor ?? this.idcolor,
        nombre: nombre ?? this.nombre,
        nombreColor: nombreColor ?? this.nombreColor,
        hex: hex ?? this.hex,
        stockDisponible: stockDisponible ?? this.stockDisponible,
        costoFabricacion: costoFabricacion ?? this.costoFabricacion,
        cantidad: cantidad ?? this.cantidad,
        precio: precio ?? this.precio,
        detalles: detalles ?? this.detalles,
        total: total ?? this.total,
        descuento: descuento ?? this.descuento,
        ganancias: ganancias ?? this.ganancias,
      );
}

class VentaApliquesFormCubit extends Cubit<VentaApliquesFormState> {
  final VentasApliquesRepository ventasApliquesRepository;
  final int idsucursal;

  VentaApliquesFormCubit({
    required this.ventasApliquesRepository,
    required this.idsucursal,
  }) : super(VentaApliquesFormState());

  bool _isValidDouble(String value) => double.tryParse(value) != null;
  double _toDouble(String value) => double.tryParse(value)!;

  // Devuelve null si se agregó, o el mensaje de error a mostrar.
  String? addDetalle() {
    if (state.idapliques == 0) return 'Seleccione un aplique';
    if (state.idcolor == 0) return 'Seleccione un color';
    if (!_isValidDouble(state.cantidad)) return 'Ingrese una cantidad válida';
    if (!_isValidDouble(state.precio)) return 'Ingrese un precio válido';

    final double cantidad = _toDouble(state.cantidad);
    final double precio = _toDouble(state.precio);
    if (cantidad <= 0) return 'La cantidad debe ser mayor a 0';
    if (precio <= 0) return 'El precio debe ser mayor a 0';

    final enCarrito = state.detalles
        .where((e) =>
            e['idapliques'] == state.idapliques &&
            e['idcolor'] == state.idcolor)
        .fold<double>(
            0, (sum, e) => sum + (e['cantidad'] as num).toDouble());
    if (enCarrito + cantidad > state.stockDisponible) {
      return 'Stock insuficiente. Disponible: ${state.stockDisponible}';
    }

    final totalLinea = (cantidad * precio * 100).round() / 100.0;
    final gananciaLinea =
        (((precio - state.costoFabricacion) * cantidad) * 100).round() / 100.0;
    final nombreLinea = '${state.nombre} (${state.nombreColor})';

    final detalles = List<Map<String, dynamic>>.from(state.detalles);
    final existingIndex = detalles.indexWhere((e) =>
        e['idapliques'] == state.idapliques &&
        e['idcolor'] == state.idcolor &&
        e['precio'] == precio);

    if (existingIndex != -1) {
      final existing = detalles[existingIndex];
      final nuevaCantidad =
          (existing['cantidad'] as num).toDouble() + cantidad;
      detalles[existingIndex] = {
        ...existing,
        'cantidad': nuevaCantidad,
        'total': (nuevaCantidad * precio * 100).round() / 100.0,
        'ganancias':
            (((precio - state.costoFabricacion) * nuevaCantidad) * 100)
                    .round() /
                100.0,
      };
    } else {
      detalles.insert(0, {
        'idapliques': state.idapliques,
        'idcolor': state.idcolor,
        'nombre': nombreLinea,
        'cantidad': cantidad,
        'precio': precio,
        'total': totalLinea,
        'ganancias': gananciaLinea,
      });
    }

    emit(state.copyWith(
      detalles: detalles,
      total: state.total + totalLinea,
      ganancias: state.ganancias + gananciaLinea,
      cantidad: '',
      precio: '',
    ));
    return null;
  }

  void removeDetalle(
      int idapliques, int idcolor, double cantidad, double precio) {
    final index = state.detalles.indexWhere((e) =>
        e['idapliques'] == idapliques &&
        e['idcolor'] == idcolor &&
        e['cantidad'] == cantidad &&
        e['precio'] == precio);
    if (index == -1) return;
    final detalles = List<Map<String, dynamic>>.from(state.detalles);
    final removed = detalles.removeAt(index);
    emit(state.copyWith(
      detalles: detalles,
      total: state.total - (removed['total'] as num).toDouble(),
      ganancias: state.ganancias - (removed['ganancias'] as num).toDouble(),
    ));
  }

  Future<bool> onFormSubmit() async {
    try {
      if (state.detalles.isEmpty) return false;
      if (state.descuento == '') onDescuentoChanged('0');
      if (!_isValidDouble(state.descuento)) return false;

      final descuento = _toDouble(state.descuento);
      final total = state.total - descuento;
      if (total < 0) return false;

      await ventasApliquesRepository.createVentaAplique(
        idsucursales: idsucursal,
        total: total,
        ganancias: state.ganancias,
        descuento: descuento,
        detalles: state.detalles,
      );

      return true;
    } catch (e) {
      debugPrint('Error al crear venta de apliques: $e');
      return false;
    }
  }

  void onApliqueChanged(Aplique? value) {
    emit(state.copyWith(
      idapliques: value?.id ?? 0,
      nombre: value?.nombre ?? '',
      costoFabricacion: value?.costoFabricacion ?? 0,
      idcolor: 0,
      nombreColor: '',
      hex: '',
      stockDisponible: 0,
    ));
  }

  void onColorChanged(StockAplique? value) {
    emit(state.copyWith(
      idcolor: value?.colorId ?? 0,
      nombreColor: value?.colorNombre ?? '',
      hex: value?.hex ?? '',
      stockDisponible: value?.stock ?? 0,
    ));
  }

  void onCantidadChanged(String value) => emit(state.copyWith(cantidad: value));
  void onPrecioChanged(String value) => emit(state.copyWith(precio: value));
  void onDescuentoChanged(String value) =>
      emit(state.copyWith(descuento: value));
}
