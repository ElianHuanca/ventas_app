import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Envuelve una [DataTable] para que nunca recorte su última columna (el
/// botón de borrar la línea).
///
/// Mientras entra se dibuja igual que la tabla sola: recibe el mismo ancho y
/// parte en líneas los textos largos. Si ni con las columnas al mínimo entra
/// (celular chico con la letra grande), toma ese ancho mínimo y se desplaza
/// de costado. Sin esto la tabla se cortaba sin aviso y la columna de borrar
/// quedaba fuera de alcance.
class TablaDesplazable extends StatelessWidget {
  final Widget child;

  const TablaDesplazable({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) return child;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _AnchoDisponible(
            minimo: constraints.minWidth,
            maximo: constraints.maxWidth,
            child: child,
          ),
        );
      },
    );
  }
}

/// Le pasa a su hijo el ancho que había fuera del SingleChildScrollView
/// ([minimo]..[maximo]); solo si su ancho mínimo intrínseco no entra, estira
/// el máximo hasta ese mínimo.
class _AnchoDisponible extends SingleChildRenderObjectWidget {
  final double minimo;
  final double maximo;

  const _AnchoDisponible({
    required this.minimo,
    required this.maximo,
    required super.child,
  });

  @override
  _RenderAnchoDisponible createRenderObject(BuildContext context) =>
      _RenderAnchoDisponible(minimo: minimo, maximo: maximo);

  @override
  void updateRenderObject(
      BuildContext context, _RenderAnchoDisponible renderObject) {
    renderObject
      ..minimo = minimo
      ..maximo = maximo;
  }
}

class _RenderAnchoDisponible extends RenderProxyBox {
  _RenderAnchoDisponible({required double minimo, required double maximo})
      : _minimo = minimo,
        _maximo = maximo;

  double _minimo;
  set minimo(double valor) {
    if (valor == _minimo) return;
    _minimo = valor;
    markNeedsLayout();
  }

  double _maximo;
  set maximo(double valor) {
    if (valor == _maximo) return;
    _maximo = valor;
    markNeedsLayout();
  }

  BoxConstraints _paraElHijo(RenderBox hijo, BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: _minimo,
        maxWidth: math.max(_maximo, hijo.getMinIntrinsicWidth(double.infinity)),
        minHeight: constraints.minHeight,
        maxHeight: constraints.maxHeight,
      );

  @override
  void performLayout() {
    final hijo = child;
    if (hijo == null) {
      size = constraints.smallest;
      return;
    }
    hijo.layout(_paraElHijo(hijo, constraints), parentUsesSize: true);
    size = constraints.constrain(hijo.size);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final hijo = child;
    if (hijo == null) return constraints.smallest;
    return constraints
        .constrain(hijo.getDryLayout(_paraElHijo(hijo, constraints)));
  }
}
