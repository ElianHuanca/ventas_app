import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';

import '../bloc/inventario_cubit.dart';

/// Abre la hoja de compartir del sistema con un PDF (el usuario elige
/// WhatsApp y el contacto). Se inyecta para los tests.
typedef CompartirPdf = Future<bool> Function(Uint8List pdf, String nombre);

Future<bool> compartirPdfSistema(Uint8List pdf, String nombre) async {
  try {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(pdf, mimeType: 'application/pdf')],
      fileNameOverrides: [nombre],
    ));
    return true;
  } on PlatformException {
    return false;
  }
}

/// Inventario de apliques de una sucursal: qué falta, cuánto hacer de cada
/// uno, y la lista (PDF o texto) para mandarle al fabricante.
class InventarioScreen extends StatelessWidget {
  final int idsucursal;
  final CompartirPdf compartirPdf;

  const InventarioScreen({
    super.key,
    required this.idsucursal,
    this.compartirPdf = compartirPdfSistema,
  });

  @override
  Widget build(BuildContext context) {
    final sucursal = context.select<SucursalesBloc, String>((b) =>
        b.state.sucursales
            .where((s) => s.id == idsucursal)
            .firstOrNull
            ?.nombre ??
        '');
    final textos = Theme.of(context).textTheme;

    return BlocBuilder<InventarioCubit, InventarioState>(
      builder: (context, state) {
        final hayFaltantes = !state.isLoading && state.faltantes.isNotEmpty;
        final nombre = sucursal.isEmpty ? 'sucursal $idsucursal' : sucursal;
        String mensaje() => mensajeFaltantes(
              sucursal: nombre,
              fecha: state.fecha,
              faltantes: ordenParaFabricante(state.faltantes),
            );

        return Scaffold(
          appBar: AppBar(
            title: Column(
              children: [
                Text('Inventario', style: textos.titleSmall),
                if (sucursal.isNotEmpty)
                  Text(
                    sucursal,
                    style: textos.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            centerTitle: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
            ),
            actions: [
              IconButton(
                tooltip: 'Copiar lista',
                icon: const Icon(Icons.copy_rounded),
                onPressed:
                    hayFaltantes ? () => _copiar(context, mensaje()) : null,
              ),
            ],
          ),
          body: _Cuerpo(state: state),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Compartir PDF'),
                onPressed: hayFaltantes
                    ? () => _compartir(context, nombre, state)
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _compartir(
      BuildContext context, String sucursal, InventarioState state) async {
    final pdf = await pdfFaltantes(
      sucursal: sucursal,
      fecha: state.fecha,
      faltantes: state.faltantes,
    );
    final compartio = await compartirPdf(
        pdf, nombrePdfFaltantes(sucursal: sucursal, fecha: state.fecha));
    if (!compartio && context.mounted) {
      showSnackbar(context, 'No se pudo compartir el PDF: usá "Copiar lista"');
    }
  }

  Future<void> _copiar(BuildContext context, String mensaje) async {
    await Clipboard.setData(ClipboardData(text: mensaje));
    if (context.mounted) {
      showSnackbar(context, 'Lista copiada: pegala en WhatsApp');
    }
  }
}

class _Cuerpo extends StatelessWidget {
  final InventarioState state;
  const _Cuerpo({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
        child: Column(
          children: [
            const Text(
              'No se pudo cargar el inventario. Revisá la conexión.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.read<InventarioCubit>().cargar(),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 60, 24, 0),
        child: Text(
          'Esta tienda no tiene apliques en el inventario.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    final visibles = state.visibles;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        _Resumen(state: state),
        if (state.estimada) ...[
          const SizedBox(height: 8),
          const _AvisoEstimada(),
        ],
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: true,
              label: Text('Faltan (${state.faltantes.length})'),
            ),
            ButtonSegment(
              value: false,
              label: Text('Todos (${state.items.length})'),
            ),
          ],
          selected: {state.soloFaltantes},
          onSelectionChanged: (_) =>
              context.read<InventarioCubit>().toggleSoloFaltantes(),
        ),
        const SizedBox(height: 12),
        if (visibles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Tocá "Todos" para ver el stock de cada color.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
        for (final r in visibles) _Fila(reposicion: r),
        const SizedBox(height: 12),
        Text(
          'Falta cuando el stock no alcanza para $_semanasMinimo semanas de '
          'venta (hasta ${_semanas(ReglaReposicion.semanasEntrega)} de '
          'entrega + ${_semanas(ReglaReposicion.semanasColchon)} de '
          'colchón); se pide hasta cubrir el doble. La venta es la de las '
          'últimas ${ReglaReposicion.semanasVentana} semanas.',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

/// 2.5 / 1 (con punto, como el resto de los números de la app).
String _semanas(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

final _semanasMinimo =
    _semanas(ReglaReposicion.semanasEntrega + ReglaReposicion.semanasColchon);

class _Resumen extends StatelessWidget {
  final InventarioState state;
  const _Resumen({required this.state});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final cantidad = state.faltantes.length;
    final (titulo, detalle) = cantidad == 0
        ? (
            'No falta nada',
            'Todo alcanza para más de $_semanasMinimo semanas de venta.',
          )
        : (
            cantidad == 1 ? '1 para reponer' : '$cantidad para reponer',
            'Hacer ${state.totalAHacer} en total',
          );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colores.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            cantidad == 0
                ? Icons.check_circle_rounded
                : Icons.inventory_2_rounded,
            color: colores.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colores.onPrimaryContainer,
                  ),
                ),
                Text(detalle,
                    style: TextStyle(color: colores.onPrimaryContainer)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisoEstimada extends StatelessWidget {
  const _AvisoEstimada();

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colores.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: colores.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Esta tienda no vendió apliques en las últimas '
              '${ReglaReposicion.semanasVentana} semanas: se estima con lo '
              'que venden las otras.',
              style: TextStyle(color: colores.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  final Reposicion reposicion;
  const _Fila({required this.reposicion});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final r = reposicion;
    // Estimada: la venta es la de las otras sucursales, no la de esta
    final venta = r.porSemana > 0
        ? '${r.estimada ? 'se estiman' : 'vende'} '
            '${_semanas(r.porSemana)} por semana'
        : 'sin ventas en ${ReglaReposicion.semanasVentana} semanas';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            MuestraColor(hex: r.item.hex, radio: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.item.aplique,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text('${r.item.color} · $venta',
                      style: const TextStyle(color: Colors.black54)),
                  Text(
                    'Quedan ${cantidadLegible(r.item.stock)}'
                    '${r.minimo > 0 ? ' · mínimo ${r.minimo}' : ''}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            if (r.faltante) ...[
              const SizedBox(width: 12),
              Column(
                children: [
                  Text('Hacer',
                      style: TextStyle(fontSize: 12, color: colores.error)),
                  Text(
                    '${r.hacer}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colores.error,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
