import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../bloc/dashboard_cubit.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        return Screen1(
          backRoute: false,
          title: 'Dashboard',
          isGridview: false,
          widget: [
            _RangoFechas(state: state),
            const SizedBox(height: 12),
            if (!state.isLoading && state.resumen != null) ...[
              const _ResumenTitulo('Telas'),
              _ResumenCards(resumen: state.resumen!),
              if (state.resumenApliques != null) ...[
                const SizedBox(height: 12),
                const _ResumenTitulo('Apliques'),
                _ResumenCards(resumen: state.resumenApliques!),
              ],
            ],
            const SizedBox(height: 12),
            _ToggleVista(verPorCantidad: state.verPorCantidad),
            const SizedBox(height: 12),
            state.isLoading
                ? const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _TopProductos(
                    productos: state.verPorCantidad
                        ? state.topProductosPorCantidad
                        : state.topProductos,
                    verPorCantidad: state.verPorCantidad,
                  ),
          ],
        );
      },
    );
  }
}

class _RangoFechas extends StatelessWidget {
  final DashboardState state;
  const _RangoFechas({required this.state});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final rango = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            initialDateRange: DateTimeRange(
              start: state.desde,
              end: state.hasta,
            ),
            locale: const Locale('es'),
            builder: (context, child) => Theme(
              data: Theme.of(context),
              child: child!,
            ),
          );
          if (rango != null && context.mounted) {
            context
                .read<DashboardCubit>()
                .cambiarRango(rango.start, rango.end);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Período',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onPrimaryContainer.withValues(alpha: .7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_fmt(state.desde)}  →  ${_fmt(state.hasta)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              Icon(Icons.date_range_rounded,
                  color: colorScheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumenTitulo extends StatelessWidget {
  final String texto;
  const _ResumenTitulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black45,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ResumenCards extends StatelessWidget {
  final ResumenVentas resumen;
  const _ResumenCards({required this.resumen});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _Card(
            label: 'Total',
            valor: '${resumen.total.toStringAsFixed(2)} Bs',
            icon: Icons.attach_money_rounded,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          _Card(
            label: 'Ganancias',
            valor: '${resumen.ganancias.toStringAsFixed(2)} Bs',
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 10),
          _Card(
            label: 'Descuentos',
            valor: '${resumen.descuento.toStringAsFixed(2)} Bs',
            icon: Icons.discount_rounded,
            color: const Color(0xFFE65100),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String label;
  final String valor;
  final IconData icon;
  final Color color;

  const _Card({
    required this.label,
    required this.valor,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valor,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleVista extends StatelessWidget {
  final bool verPorCantidad;
  const _ToggleVista({required this.verPorCantidad});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: verPorCantidad
                  ? () => context.read<DashboardCubit>().toggleVista()
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !verPorCantidad
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(10)),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Por monto',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: !verPorCantidad
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: !verPorCantidad
                  ? () => context.read<DashboardCubit>().toggleVista()
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: verPorCantidad
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(10)),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Por cantidad',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: verPorCantidad
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopProductos extends StatelessWidget {
  final List<TopProducto> productos;
  final bool verPorCantidad;
  const _TopProductos({required this.productos, required this.verPorCantidad});

  @override
  Widget build(BuildContext context) {
    if (productos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(
          child: Text(
            'Sin ventas en el período seleccionado',
            style: TextStyle(color: Colors.black38, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    final maxTotal = verPorCantidad
        ? productos.first.totalCantidad.toDouble()
        : productos.first.totalVendido;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Todos los productos por ${verPorCantidad ? 'cantidad vendida' : 'total vendido'} (${productos.length})',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          ...productos.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final valor = verPorCantidad
                ? p.totalCantidad.toDouble()
                : p.totalVendido;
            final ratio = maxTotal > 0 ? valor / maxTotal : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .06),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Número de ranking
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == 0
                          ? const Color(0xFFFFD700)
                          : i == 1
                              ? const Color(0xFFC0C0C0)
                              : i == 2
                                  ? const Color(0xFFCD7F32)
                                  : colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: i < 3
                            ? Colors.white
                            : colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nombre,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 6,
                            backgroundColor: colorScheme.primaryContainer
                                .withValues(alpha: .4),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    verPorCantidad
                        ? '${p.totalCantidad} uds'
                        : '${p.totalVendido.toStringAsFixed(2)} Bs',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
