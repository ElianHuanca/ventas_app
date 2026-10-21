import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/shared/clave_de_operacion.dart';
import '../../domain/domain.dart';

class DetalleVentaFormState {
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
  final VentasRepository ventasRepository;
  final int idsucursal;

  /// Clave de idempotencia del envío: la misma en los reintentos del mismo
  /// carrito (si se perdió la respuesta, la base no lo suma dos veces).
  final _clave = ClaveDeOperacion();

  DetalleVentaFormCubit({
    required this.ventasRepository,
    required this.idsucursal,
  }) : super(DetalleVentaFormState());

  // "NaN" e "Infinity" también los parsea double.tryParse
  bool _isValidDouble(String value) =>
      double.tryParse(value)?.isFinite ?? false;
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
          _sinRuido((existing['cantidad'] as num).toDouble() + cantidad);
      final nuevoTotal = _centavos(nuevaCantidad * precio);
      final nuevasGanancias = precxcompra == 0
          ? 0.0
          : _centavos((precio - precxcompra) * nuevaCantidad);
      // El carrito sube lo que subió la línea: sumar el redondeo de cada
      // agregado por separado lo descuadraba (0.5 m + 0.5 m a 0.01 Bs:
      // línea 0.01, total 0.02, y al quitarla quedaba 0.01).
      totalDelta = nuevoTotal - (existing['total'] as num).toDouble();
      gananciasDelta =
          nuevasGanancias - (existing['ganancias'] as num).toDouble();
      detVentas[existingIndex] = {
        ...existing,
        'cantidad': nuevaCantidad,
        'total': nuevoTotal,
        'ganancias': nuevasGanancias,
      };
    } else {
      totalDelta = _centavos(cantidad * precio);
      gananciasDelta =
          precxcompra == 0 ? 0 : _centavos((precio - precxcompra) * cantidad);
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
      total: _centavos(state.total + totalDelta),
      ganancias: _centavos(state.ganancias + gananciasDelta),
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
      total: _centavos(state.total - (removed['total'] as num).toDouble()),
      ganancias:
          _centavos(state.ganancias - (removed['ganancias'] as num).toDouble()),
    ));
  }

  /// true mientras se envía la venta. Un segundo envío en ese lapso (doble
  /// toque en "Guardar") se ignora: mandaría el carrito otra vez y la base
  /// sumaría las cantidades y el total dos veces.
  bool get enviando => _enviando;
  bool _enviando = false;

  /// Registra el carrito en una sola llamada (RPC `registrar_venta_telas`):
  /// la venta del día de la sucursal, sus líneas y sus totales quedan todos
  /// o ninguno. Si falla, el carrito queda para volver a tocar Guardar: el
  /// reintento del mismo carrito lleva la misma clave de operación y, si el
  /// primero había llegado a la base (respuesta perdida), no se suma de
  /// nuevo. La clave se renueva cuando cambia el carrito, el descuento o el
  /// día, y después de un envío que salió bien.
  Future<bool> onFormSubmit() async {
    if (_enviando) return false;
    _enviando = true;
    try {
      if (state.detVentas.isEmpty) return false;
      if (state.descuento == '') onDescuentoChanged('0');
      if (!_isValidDouble(state.descuento)) return false;

      final descuento = _toDouble(state.descuento);
      final idOperacion = _clave.para({
        'detalles': state.detVentas,
        'descuento': descuento,
        // La venta es la del día: la hora no la cambia
        'dia': state.fecha.toIso8601String().substring(0, 10),
      });
      await ventasRepository.registrarVentaTelas(
        idsucursal: idsucursal,
        fecha: state.fecha,
        detalles: state.detVentas,
        descuento: descuento,
        idOperacion: idOperacion,
      );
      _clave.descartar();
      return true;
    } catch (e) {
      debugPrint('Error al registrar la venta de telas: $e');
      return false;
    } finally {
      _enviando = false;
    }
  }

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

/// Redondea a centavos, la mitad hacia arriba como `numeric` en Postgres.
/// Sumar doubles arrastra ruido (10.1 + 20.2 da 30.299999999999997) y el
/// double de cantidad × precio no es el decimal exacto: 3.75 × 23.22 da
/// 87.07499999999999 y redondeado directo quedaba 87.07 en vez de 87.08.
/// Primero se quita el ruido a 6 decimales (las cantidades y precios
/// tipeados tienen menos) y recién ahí se redondea la mitad del centavo.
double _centavos(double valor) =>
    ((valor * 1000000).round() / 10000).round() / 100.0;

/// Quita el ruido de sumar cantidades (0.3 + 0.6 daba 0.8999999999999999
/// mts en la línea). A 6 decimales: no cambia ninguna cantidad tipeada.
double _sinRuido(double valor) => (valor * 1000000).round() / 1000000.0;
