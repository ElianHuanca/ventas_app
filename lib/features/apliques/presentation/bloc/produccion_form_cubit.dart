import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/shared/clave_de_operacion.dart';
import '../../domain/domain.dart';

class ProduccionFormState {
  final bool isLoading;
  final bool isSubmitting;
  final List<Aplique> apliques;
  final List<StockAplique> stock;
  final List<ColorItem> colores;
  final int idsucursal;
  final int idapliques;
  final String apliqueNombre;
  final int idcolor;
  final String colorNombre;
  final String colorHex;
  final String cantidad;
  final DateTime fecha;
  final List<Map<String, dynamic>> detProducciones;

  ProduccionFormState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.apliques = const [],
    this.stock = const [],
    this.colores = const [],
    this.idsucursal = 0,
    this.idapliques = 0,
    this.apliqueNombre = '',
    this.idcolor = 0,
    this.colorNombre = '',
    this.colorHex = '',
    this.cantidad = '',
    this.detProducciones = const [],
    DateTime? fecha,
  }) : fecha = fecha ?? DateTime.now();

  /// Stock actual del aplique+color seleccionados en la sucursal de la ruta.
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
    String? apliqueNombre,
    int? idcolor,
    String? colorNombre,
    String? colorHex,
    String? cantidad,
    DateTime? fecha,
    List<Map<String, dynamic>>? detProducciones,
  }) =>
      ProduccionFormState(
        isLoading: isLoading ?? this.isLoading,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        apliques: apliques ?? this.apliques,
        stock: stock ?? this.stock,
        colores: colores ?? this.colores,
        idsucursal: idsucursal ?? this.idsucursal,
        idapliques: idapliques ?? this.idapliques,
        apliqueNombre: apliqueNombre ?? this.apliqueNombre,
        idcolor: idcolor ?? this.idcolor,
        colorNombre: colorNombre ?? this.colorNombre,
        colorHex: colorHex ?? this.colorHex,
        cantidad: cantidad ?? this.cantidad,
        fecha: fecha ?? this.fecha,
        detProducciones: detProducciones ?? this.detProducciones,
      );
}

class ProduccionFormCubit extends Cubit<ProduccionFormState> {
  final ApliquesRepository apliquesRepository;
  final int idsucursal;

  /// Clave de idempotencia del envío: la misma en los reintentos del mismo
  /// listado (si se perdió la respuesta, la base no suma el stock dos veces).
  final _clave = ClaveDeOperacion();

  ProduccionFormCubit({
    required this.apliquesRepository,
    required this.idsucursal,
  }) : super(ProduccionFormState(idsucursal: idsucursal)) {
    unawaited(load());
  }

  Future<void> load() async {
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

  /// Solo se ofrecen los colores vinculados al aplique (aplique_colores).
  Future<void> onApliqueChanged(Aplique? value) async {
    final id = value?.id ?? 0;
    emit(state.copyWith(
      idapliques: id,
      apliqueNombre: value?.nombre ?? '',
      idcolor: 0,
      colorNombre: '',
      colorHex: '',
      colores: [],
    ));
    if (id == 0) return;
    try {
      final colores = await apliquesRepository.getColoresAplique(id);
      emit(state.copyWith(colores: colores.where((e) => e.vinculado).toList()));
    } catch (_) {}
  }

  void onColorChanged(ColorItem? value) => emit(state.copyWith(
        idcolor: value?.id ?? 0,
        colorNombre: value?.nombre ?? '',
        colorHex: value?.hex ?? '',
      ));
  void onCantidadChanged(String value) => emit(state.copyWith(cantidad: value));
  void onFechaChanged(DateTime value) => emit(state.copyWith(fecha: value));

  /// Añade la línea (aplique+color+cantidad) al listado. Si ya existe una
  /// línea con el mismo aplique+color, suma la cantidad (igual que ventas
  /// hace merge por idtelas+precio). Devuelve null si se añadió, o el
  /// mensaje de error a mostrar.
  String? addDetalleProduccion() {
    if (state.idapliques == 0) return 'Seleccione un aplique';
    if (state.idcolor == 0) return 'Seleccione un color';
    final cantidad = double.tryParse(state.cantidad);
    // "NaN" e "Infinity" también los parsea double.tryParse
    if (cantidad == null || !cantidad.isFinite || cantidad <= 0) {
      return 'Ingrese una cantidad válida mayor a 0';
    }

    final detProducciones =
        List<Map<String, dynamic>>.from(state.detProducciones);
    final existingIndex = detProducciones.indexWhere((e) =>
        e['idaplique'] == state.idapliques && e['idcolor'] == state.idcolor);

    if (existingIndex != -1) {
      final existing = detProducciones[existingIndex];
      detProducciones[existingIndex] = {
        ...existing,
        'cantidad':
            _sinRuido((existing['cantidad'] as num).toDouble() + cantidad),
      };
    } else {
      detProducciones.insert(0, {
        'idaplique': state.idapliques,
        'apliqueNombre': state.apliqueNombre,
        'idcolor': state.idcolor,
        'colorNombre': state.colorNombre,
        'hex': state.colorHex,
        'cantidad': cantidad,
      });
    }

    emit(state.copyWith(detProducciones: detProducciones, cantidad: ''));
    return null;
  }

  int _obtenerIndex(int idaplique, int idcolor, double cantidad) {
    return state.detProducciones.indexWhere((e) =>
        e['idaplique'] == idaplique &&
        e['idcolor'] == idcolor &&
        e['cantidad'] == cantidad);
  }

  void removeDetalleProduccion(int idaplique, int idcolor, double cantidad) {
    final index = _obtenerIndex(idaplique, idcolor, cantidad);
    if (index == -1) return;
    final detProducciones =
        List<Map<String, dynamic>>.from(state.detProducciones);
    detProducciones.removeAt(index);
    emit(state.copyWith(detProducciones: detProducciones));
  }

  /// Registra todas las líneas del listado y refresca el stock. El propio
  /// datasource crea/reusa la cabecera de la sucursal+fecha y hace upsert
  /// por línea, sumando la cantidad si el aplique+color ya se fabricó ese
  /// día. Devuelve null si se registró, o el mensaje de error a mostrar.
  /// Con un registro en curso (doble toque en "Guardar") no hace nada: no es
  /// null porque todavía no se registró.
  ///
  /// Si falla el registro, el listado queda para volver a tocar Guardar: el
  /// reintento del mismo listado lleva la misma clave de operación y, si el
  /// primero había llegado (respuesta perdida), la base no lo suma de nuevo.
  /// La clave se renueva cuando cambia el listado o el día, y después de un
  /// registro que salió bien.
  Future<String?> onFormSubmit() async {
    if (state.isSubmitting) return 'Ya se está registrando la producción';
    if (state.detProducciones.isEmpty) {
      return 'Añada al menos una línea al listado';
    }

    emit(state.copyWith(isSubmitting: true));
    try {
      final lineas = state.detProducciones
          .map((e) => {
                'idaplique': e['idaplique'] as int,
                'idcolor': e['idcolor'] as int,
                'cantidad': (e['cantidad'] as num).toDouble(),
              })
          .toList();
      final idOperacion = _clave.para({
        'lineas': lineas,
        // La producción es la del día: la hora no la cambia
        'dia': state.fecha.toIso8601String().substring(0, 10),
      });
      await apliquesRepository.createProduccion(
        sucursalId: state.idsucursal,
        fecha: state.fecha,
        lineas: lineas,
        idOperacion: idOperacion,
      );
      _clave.descartar();
    } catch (e) {
      emit(state.copyWith(isSubmitting: false));
      return e.toString().replaceFirst('Exception: ', '');
    }

    // Ya quedó registrada: el listado se vacía aunque falle el refresco del
    // stock. Antes un getStock fallido devolvía el error con el listado
    // lleno y el usuario volvía a registrar lo mismo.
    emit(state.copyWith(detProducciones: []));
    try {
      final stock = await apliquesRepository.getStock(state.idsucursal);
      emit(state.copyWith(stock: stock));
    } catch (_) {
      // El stock que muestra la pantalla queda viejo hasta la próxima carga
    } finally {
      emit(state.copyWith(isSubmitting: false));
    }
    return null;
  }
}

/// Quita el ruido de sumar cantidades (1.03 + 1 + 1.23 daba
/// 3.2600000000000002 uds). A 6 decimales: no cambia ninguna cantidad
/// tipeada.
double _sinRuido(double valor) => (valor * 1000000).round() / 1000000.0;
