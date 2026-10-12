import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../bloc/dashboard_cubit.dart';

/// Una pestaña por línea de negocio (Telas | Apliques) con el período
/// compartido arriba. Ambas se cargan juntas en el cubit.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        drawer: const SideMenu(),
        appBar: AppBar(
          title:
              Text('Dashboard', style: Theme.of(context).textTheme.titleSmall),
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(15),
            ),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.checkroom_rounded), text: 'Telas'),
              Tab(icon: Icon(Icons.auto_awesome_rounded), text: 'Apliques'),
            ],
          ),
        ),
        body: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            return Column(
              children: [
                _RangoFechas(state: state),
                Expanded(
                  child: TabBarView(
                    children: [
                      _PestanaVentas(
                        state: state,
                        resumen: state.resumenTelas,
                        productos: state.telasOrdenadas,
                        plural: 'telas',
                        unidad: 'mts',
                      ),
                      _PestanaVentas(
                        state: state,
                        resumen: state.resumenApliques,
                        productos: state.apliquesOrdenados,
                        plural: 'apliques',
                        unidad: 'uds',
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PestanaVentas extends StatelessWidget {
  final DashboardState state;
  final ResumenVentas? resumen;
  final List<TopProducto> productos;
  final String plural;
  final String unidad;

  const _PestanaVentas({
    required this.state,
    required this.resumen,
    required this.productos,
    required this.plural,
    required this.unidad,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      children: [
        if (!state.isLoading && resumen != null) ...[
          _ResumenCards(resumen: resumen!),
          const SizedBox(height: 12),
        ],
        _ToggleVista(verPorCantidad: state.verPorCantidad),
        const SizedBox(height: 12),
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.error)
          const _ErrorDeCarga()
        else
          _TopProductos(
            productos: productos,
            verPorCantidad: state.verPorCantidad,
            plural: plural,
            unidad: unidad,
          ),
      ],
    );
  }
}

/// La carga falló: se dice, en vez de mostrar el período como sin ventas.
class _ErrorDeCarga extends StatelessWidget {
  const _ErrorDeCarga();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Text(
            'No se pudieron cargar las ventas. Revisá la conexión.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.read<DashboardCubit>().cargar(),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
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
            context.read<DashboardCubit>().cambiarRango(rango.start, rango.end);
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
                      color:
                          colorScheme.onPrimaryContainer.withValues(alpha: .7),
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
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(10)),
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
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(10)),
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
  final String plural;
  final String unidad;
  const _TopProductos({
    required this.productos,
    required this.verPorCantidad,
    required this.plural,
    required this.unidad,
  });

  // 12 mts / 2.50 mts: los metros de tela pueden tener decimales
  static String _cantidad(double c) =>
      c == c.roundToDouble() ? c.toStringAsFixed(0) : c.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    if (productos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: Text(
            'Sin ventas de $plural en el período seleccionado',
            style: const TextStyle(
                color: Colors.black38, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    final maxTotal = verPorCantidad
        ? productos.first.totalCantidad
        : productos.first.totalVendido;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${productos.length} $plural por ${verPorCantidad ? 'cantidad vendida' : 'total vendido'}',
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
            final valor = verPorCantidad ? p.totalCantidad : p.totalVendido;
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
                        ? '${_cantidad(p.totalCantidad)} $unidad'
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
