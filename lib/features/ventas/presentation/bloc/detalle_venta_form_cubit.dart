import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DetalleVentaFormState {
  final int idventa;
  final int idtelas;
  final String nombre;
  final String cantidad;
  final String precio;
  final double precxcompra;
  final double total;
  final List<Map<String, dynamic>> detVentas;
  final String descuento;
  final double ganancias;
  final DateTime fecha;

  DetalleVentaFormState({
    this.idventa = 0,
    this.idtelas = 0,
    this.precxcompra = 0,
    this.cantidad = '',
    this.precio = '',
    this.nombre = '',
    this.detVentas = const [],
    this.total = 0,
    this.descuento = '',
    this.ganancias = 0,
    DateTime? fecha,
  }) : fecha = fecha ?? DateTime.now();

  DetalleVentaFormState copyWith({
    int? idventa,
    int? idtelas,
    String? cantidad,
    String? precio,
    String? nombre,
    double? total,
    List<Map<String, dynamic>>? detVentas,
    double? precxcompra,
    String? descuento,
    double? ganancias,
    DateTime? fecha,
  }) =>
      DetalleVentaFormState(
        idventa: idventa ?? this.idventa,
        idtelas: idtelas ?? this.idtelas,
        cantidad: cantidad ?? this.cantidad,
        precio: precio ?? this.precio,
        nombre: nombre ?? this.nombre,
        total: total ?? this.total,
        detVentas: detVentas ?? this.detVentas,
        precxcompra: precxcompra ?? this.precxcompra,
        descuento: descuento ?? this.descuento,
        ganancias: ganancias ?? this.ganancias,
        fecha: fecha ?? this.fecha,
      );
}

class DetalleVentaFormCubit extends Cubit<DetalleVentaFormState> {
  final Future<bool> Function(List<Map<String, dynamic>>) onSubmitCallback;
  final Future<bool> Function(Map<String, dynamic>) onUpdateCallback;

  DetalleVentaFormCubit({
    required this.onSubmitCallback,
    required this.onUpdateCallback,
    required int idventa,
    DateTime? initialFecha,
  }) : super(DetalleVentaFormState(idventa: idventa, fecha: initialFecha));

  bool _isValidDouble(String value) => double.tryParse(value) != null;
  double _toDouble(String value) => double.tryParse(value)!;

  void addDetalleVenta() {
    if (state.idtelas == 0 ||
        !_isValidDouble(state.cantidad) ||
        !_isValidDouble(state.precio)) {
      return;
    }
    final double cantidad = _toDouble(state.cantidad);
    final double precio = _toDouble(state.precio);
    final double precxcompra = state.precxcompra;
    if (cantidad <= 0 || precio <= 0) return;

    final existingIndex = state.detVentas.indexWhere(
      (e) => e['idtelas'] == state.idtelas && e['precio'] == precio,
    );

    final detVentas = List<Map<String, dynamic>>.from(state.detVentas);
    double totalDelta;
    double gananciasDelta;

    if (existingIndex != -1) {
      final existing = detVentas[existingIndex];
      final nuevaCantidad =
          (existing['cantidad'] as num).toDouble() + cantidad;
      totalDelta = (cantidad * precio * 100).round() / 100.0;
      gananciasDelta = precxcompra == 0
          ? 0
          : (((precio - precxcompra) * cantidad) * 100).round() / 100.0;
      detVentas[existingIndex] = {
        ...existing,
        'cantidad': nuevaCantidad,
        'total': (nuevaCantidad * precio * 100).round() / 100.0,
        'ganancias': precxcompra == 0
            ? 0
            : (((precio - precxcompra) * nuevaCantidad) * 100).round() / 100.0,
      };
    } else {
      totalDelta = (cantidad * precio * 100).round() / 100.0;
      gananciasDelta = precxcompra == 0
          ? 0
          : (((precio - precxcompra) * cantidad) * 100).round() / 100.0;
      detVentas.insert(0, {
        'idtelas': state.idtelas,
        'nombre': state.nombre,
        'cantidad': cantidad,
        'precio': precio,
        'total': totalDelta,
        'ganancias': gananciasDelta,
      });
    }

    emit(state.copyWith(
      detVentas: detVentas,
      total: state.total + totalDelta,
      ganancias: state.ganancias + gananciasDelta,
      precio: '',
      cantidad: '',
    ));
  }

  int _obtenerIndex(int idtelas, double cantidad, double precio) {
    return state.detVentas.indexWhere((e) =>
        e['idtelas'] == idtelas &&
        e['cantidad'] == cantidad &&
        e['precio'] == precio);
  }

  void removeDetalleVenta(int idtelas, double cantidad, double precio) {
    final index = _obtenerIndex(idtelas, cantidad, precio);
    if (index == -1) return;
    final detVentas = List<Map<String, dynamic>>.from(state.detVentas);
    final removed = detVentas.removeAt(index);
    emit(state.copyWith(
      detVentas: detVentas,
      total: state.total - (removed['total'] as num).toDouble(),
      ganancias: state.ganancias - (removed['ganancias'] as num).toDouble(),
    ));
  }

  Future<bool> onFormSubmit() async {
    try {
      if (state.detVentas.isEmpty) return false;
      if (state.descuento == '') onDescuentoChanged('0');
      if (!_isValidDouble(state.descuento)) return false;
      final value1 = await onSubmitCallback(state.detVentas);
      final value2 = await onUpdateCallback(_toMap());
      return value1 && value2;
    } catch (e) {
      debugPrint('Error al crear detalle venta: $e');
      return false;
    }
  }

  Map<String, dynamic> _toMap() => {
        'total': state.total,
        'descuento': _toDouble(state.descuento),
        'ganancias': state.ganancias,
        'fecha': state.fecha.toIso8601String(),
      };

  void onIdTelasChanged(int value) => _updateState(idtelas: value);
  void onNombreChanged(String value) => _updateState(nombre: value);
  void onPrecioChanged(String value) => _updateState(precio: value);
  void onCantidadChanged(String value) => _updateState(cantidad: value);
  void onPrecxCompraChanged(double value) => _updateState(precxcompra: value);
  void onDescuentoChanged(String value) => _updateState(descuento: value);
  void onFechaChanged(DateTime value) => _updateState(fecha: value);

  void _updateState({
    int? idtelas,
    String? nombre,
    String? cantidad,
    String? precio,
    double? total,
    List<Map<String, dynamic>>? detVentas,
    double? precxcompra,
    String? descuento,
    double? ganancias,
    DateTime? fecha,
  }) {
    emit(state.copyWith(
      idtelas: idtelas ?? state.idtelas,
      nombre: nombre ?? state.nombre,
      cantidad: cantidad ?? state.cantidad,
      precio: precio ?? state.precio,
      total: total ?? state.total,
      detVentas: detVentas ?? state.detVentas,
      precxcompra: precxcompra ?? state.precxcompra,
      descuento: descuento ?? state.descuento,
      ganancias: ganancias ?? state.ganancias,
      fecha: fecha ?? state.fecha,
    ));
  }
}
