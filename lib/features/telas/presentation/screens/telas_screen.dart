import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../../domain/domain.dart';
import '../bloc/bloc.dart';

class TelasScreen extends StatefulWidget {
  const TelasScreen({super.key});

  @override
  State<TelasScreen> createState() => _TelasScreenState();
}

class _TelasScreenState extends State<TelasScreen> {
  // Controller propio: el TextField se destruye mientras el FullScreenLoader
  // tapa la recarga y, sin él, volvía vacío mientras la lista seguía filtrada
  final _buscador = TextEditingController();

  String get _busqueda => _buscador.text;

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TelasBloc, TelasState>(
      builder: (context, state) {
        return state.isLoading
            ? const FullScreenLoader()
            : Screen1(
                backRoute: false,
                widget: _buildBody(context, state),
                title: 'Telas',
                isGridview: false,
                tooltipAgregar: 'Agregar tela',
                onTap: () async {
                  await context.push('/tela/0');
                  if (context.mounted) {
                    context.read<TelasBloc>().add(TelasLoadRequested());
                  }
                },
              );
      },
    );
  }

  List<Widget> _buildBody(BuildContext context, TelasState state) {
    final filtradas = state.telas
        .where((t) => t.nombre.toLowerCase().contains(_busqueda.toLowerCase()))
        .toList();

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: TextField(
          controller: _buscador,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar tela...',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      if (state.telas.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('No hay telas registradas')),
        )
      else if (filtradas.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('Sin resultados para esa búsqueda')),
        )
      else
        ...filtradas.map((tela) => _telaCard(tela, context)),
    ];
  }

  Widget _telaCard(Tela tela, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tela.activo ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 3),
            color: Theme.of(context).primaryColor.withValues(alpha: .15),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.checkroom_rounded,
                  color: tela.activo
                      ? Theme.of(context).primaryColor
                      : Colors.black26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tela.nombre,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: tela.activo ? Colors.black87 : Colors.black38,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _chip('X Menor: ${tela.precxmen} Bs'),
                          _chip('X Mayor: ${tela.precxmay} Bs'),
                          _chip('X Rollo: ${tela.precxrollo} Bs'),
                          _chip('Compra: ${tela.precxcompra} Bs'),
                          if (!tela.activo)
                            _chip('Inactivo', icon: Icons.visibility_off),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/tela-colores/${tela.id}'),
                    icon: const Icon(Icons.palette_outlined, size: 16),
                    label: const Text('Colores'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await context.push('/tela/${tela.id}');
                      if (context.mounted) {
                        context.read<TelasBloc>().add(TelasLoadRequested());
                      }
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Modificar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String texto, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.black45),
            const SizedBox(width: 4),
          ],
          Text(texto,
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }
}
