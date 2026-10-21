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

  // "NaN" e "Infinity" también los parsea double.tryParse
  bool _isValidDouble(String value) =>
      double.tryParse(value)?.isFinite ?? false;
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
        .fold<double>(0, (sum, e) => sum + (e['cantidad'] as num).toDouble());
    if (_sinRuido(enCarrito + cantidad) > state.stockDisponible) {
      return 'Stock insuficiente. Disponible: ${state.stockDisponible}';
    }

    final totalLinea = _centavos(cantidad * precio);
    final gananciaLinea =
        _centavos((precio - state.costoFabricacion) * cantidad);
    final nombreLinea = '${state.nombre} (${state.nombreColor})';

    final detalles = List<Map<String, dynamic>>.from(state.detalles);
    final existingIndex = detalles.indexWhere((e) =>
        e['idapliques'] == state.idapliques &&
        e['idcolor'] == state.idcolor &&
        e['precio'] == precio);

    var totalDelta = totalLinea;
    var gananciasDelta = gananciaLinea;
    if (existingIndex != -1) {
      final existing = detalles[existingIndex];
      final nuevaCantidad =
          _sinRuido((existing['cantidad'] as num).toDouble() + cantidad);
      final nuevoTotal = _centavos(nuevaCantidad * precio);
      final nuevasGanancias =
          _centavos((precio - state.costoFabricacion) * nuevaCantidad);
      // El carrito sube lo que subió la línea: sumar el redondeo de cada
      // agregado por separado lo descuadraba de la línea.
      totalDelta = nuevoTotal - (existing['total'] as num).toDouble();
      gananciasDelta =
          nuevasGanancias - (existing['ganancias'] as num).toDouble();
      detalles[existingIndex] = {
        ...existing,
        'cantidad': nuevaCantidad,
        'total': nuevoTotal,
        'ganancias': nuevasGanancias,
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
      total: _centavos(state.total + totalDelta),
      ganancias: _centavos(state.ganancias + gananciasDelta),
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
      total: _centavos(state.total - (removed['total'] as num).toDouble()),
      ganancias:
          _centavos(state.ganancias - (removed['ganancias'] as num).toDouble()),
    ));
  }

  /// true mientras se envía la venta. Un segundo envío en ese lapso (volver
  /// a tocar "Guardar" y confirmar antes de que responda la base) se ignora:
  /// descontaría el stock y sumaría la venta dos veces.
  bool get enviando => _enviando;
  bool _enviando = false;

  Future<bool> onFormSubmit() async {
    if (_enviando) return false;
    _enviando = true;
    try {
      if (state.detalles.isEmpty) return false;
      if (state.descuento == '') onDescuentoChanged('0');
      if (!_isValidDouble(state.descuento)) return false;

      final descuento = _toDouble(state.descuento);
      final total = _centavos(state.total - descuento);
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
    } finally {
      _enviando = false;
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

/// Redondea a centavos, la mitad hacia arriba como `numeric` en Postgres.
/// Sumar doubles arrastra ruido (10.1 + 20.2 da 30.299999999999997) y el
/// double de cantidad × precio no es el decimal exacto: 1.5 × 0.15 da
/// 0.22499999999999998 y redondeado directo quedaba 0.22 en vez de 0.23.
/// Primero se quita el ruido a 6 decimales (las cantidades y precios
/// tipeados tienen menos) y recién ahí se redondea la mitad del centavo.
double _centavos(double valor) =>
    ((valor * 1000000).round() / 10000).round() / 100.0;

/// Quita el ruido de sumar cantidades (con 1.07 en el carrito y stock 2.07,
/// 1.07 + 1 daba 2.0700000000000003 y rechazaba la última unidad). A 6
/// decimales: no cambia ninguna cantidad tipeada.
double _sinRuido(double valor) => (valor * 1000000).round() / 1000000.0;
