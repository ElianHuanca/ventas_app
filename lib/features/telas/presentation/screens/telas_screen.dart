import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../../domain/domain.dart';
import '../bloc/bloc.dart';

class TelasScreen extends StatelessWidget {
  const TelasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TelasBloc, TelasState>(
      builder: (context, state) {
        return state.isLoading
            ? const FullScreenLoader()
            : Screen1(
                backRoute: false,
                widget: _buildBody(state.telas, context),
                title: 'Telas',
                isGridview: false,
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

  List<Widget> _buildBody(List<Tela> telas, BuildContext context) {
    return telas.map((tela) => _telaCard(tela, context)).toList();
  }

  Container _telaCard(Tela tela, BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 5),
            color: Theme.of(context).primaryColor.withValues(alpha: .2),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: ListTile(
        title: Text(tela.nombre),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Precio por metro: ${tela.precxmen}Bs'),
            Text('Precio por mayor: ${tela.precxmay}Bs'),
            Text('Precio por rollo: ${tela.precxrollo}Bs'),
            Text('Precio de compra: ${tela.precxcompra}Bs'),
          ],
        ),
        onTap: () async {
          await context.push('/tela/${tela.id}');
          if (context.mounted) {
            context.read<TelasBloc>().add(TelasLoadRequested());
          }
        },
      ),
    );
  }
}
