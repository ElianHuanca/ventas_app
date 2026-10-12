import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/domain.dart';

class TelaFormState {
  final int id;
  final String nombre;
  final String precxmen;
  final String precxmay;
  final String precxrollo;
  final String precxcompra;
  final bool activo;

  TelaFormState({
    this.id = 0,
    this.nombre = '',
    this.precxmen = '',
    this.precxmay = '',
    this.precxrollo = '',
    this.precxcompra = '',
    this.activo = true,
  });

  TelaFormState copyWith({
    int? id,
    String? nombre,
    String? precxmen,
    String? precxmay,
    String? precxrollo,
    String? precxcompra,
    bool? activo,
  }) =>
      TelaFormState(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        precxmen: precxmen ?? this.precxmen,
        precxmay: precxmay ?? this.precxmay,
        precxrollo: precxrollo ?? this.precxrollo,
        precxcompra: precxcompra ?? this.precxcompra,
        activo: activo ?? this.activo,
      );
}

class TelaFormCubit extends Cubit<TelaFormState> {
  final Future<bool> Function(Map<String, dynamic>) onCreateCallback;
  final Future<bool> Function(Map<String, dynamic>) onUpdateCallback;

  TelaFormCubit({
    required this.onCreateCallback,
    required this.onUpdateCallback,
    required Tela tela,
  }) : super(TelaFormState(
          id: tela.id,
          nombre: tela.nombre,
          precxmen: _precioInicial(tela.id, tela.precxmen),
          precxmay: _precioInicial(tela.id, tela.precxmay),
          precxrollo: _precioInicial(tela.id, tela.precxrollo),
          precxcompra: _precioInicial(tela.id, tela.precxcompra),
          activo: tela.activo,
        ));

  /// Una tela nueva arranca con los campos vacíos; una existente muestra su
  /// precio aunque sea 0 ("no se vende en esa modalidad"): vacío, la
  /// validación exigía reescribirlo para poder guardar.
  static String _precioInicial(int id, double? precio) {
    if (id == 0 && (precio ?? 0) == 0) return '';
    return precio?.toString() ?? '';
  }

  Future<bool> onSubmit({required bool isUpdate}) async {
    if (_isFormInvalid()) return false;
    final telaLike = _toMap();
    try {
      return isUpdate
          ? await onUpdateCallback(telaLike)
          : await onCreateCallback(telaLike);
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _toMap() {
    return {
      'id': state.id,
      'nombre': state.nombre.trim(),
      'precxmen': _tryParse(state.precxmen) ?? 0,
      'precxmay': _tryParse(state.precxmay) ?? 0,
      'precxrollo': _tryParse(state.precxrollo) ?? 0,
      'precxcompra': _tryParse(state.precxcompra) ?? 0,
      'activo': state.activo,
    };
  }

  bool _isFormInvalid() {
    final valores = [
      state.precxmen,
      state.precxmay,
      state.precxrollo,
      state.precxcompra,
    ];
    if (state.nombre.trim().isEmpty || valores.any((v) => v.isEmpty)) {
      return true;
    }
    final parseados = valores.map(_tryParse);
    return parseados.any((v) => v == null || v < 0);
  }

  double? _tryParse(String value) => double.tryParse(value);

  void onNombreChanged(String value) => _updateState(nombre: value);
  void onPrecxmenChanged(String value) => _updateState(precxmen: value);
  void onPrecxmayChanged(String value) => _updateState(precxmay: value);
  void onPrecxrolloChanged(String value) => _updateState(precxrollo: value);
  void onPrecxcompraChanged(String value) => _updateState(precxcompra: value);
  void onActivoChanged(bool value) => emit(state.copyWith(activo: value));

  void _updateState({
    String? nombre,
    String? precxmen,
    String? precxmay,
    String? precxrollo,
    String? precxcompra,
  }) {
    emit(state.copyWith(
      nombre: nombre ?? state.nombre,
      precxmen: precxmen ?? state.precxmen,
      precxmay: precxmay ?? state.precxmay,
      precxrollo: precxrollo ?? state.precxrollo,
      precxcompra: precxcompra ?? state.precxcompra,
    ));
  }
}
