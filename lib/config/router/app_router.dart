import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/dashboard/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:textiles_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:textiles_app/features/sucursales/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/sucursales/sucursales.dart';
import 'package:textiles_app/features/telas/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/telas/telas.dart';
import 'package:textiles_app/features/ventas/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/ventas/ventas.dart';

int _pathParamInt(GoRouterState state, String key, {int fallback = 0}) {
  final value = state.pathParameters[key];
  if (value == null || value.isEmpty) return fallback;
  return int.tryParse(value) ?? fallback;
}

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SucursalesScreen(false),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => BlocProvider(
          create: (_) => DashboardCubit(
            repository: DashboardRepositoryImpl(DashboardDatasourceImpl()),
          ),
          child: const DashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/sucursales',
        builder: (context, state) => const SucursalesScreen(true),
      ),
      GoRoute(
        path: '/sucursal/:idsucursal',
        builder: (context, state) {
          final id = _pathParamInt(state, 'idsucursal');
          final sucursalesBloc = context.read<SucursalesBloc>();
          final sucursalesRepo =
              SucursalesRepositoryImpl(SucursalesDatasourceImpl());
          return BlocProvider.value(
            value: sucursalesBloc,
            child: BlocProvider(
              create: (_) => SucursalBloc(
                sucursalesRepository: sucursalesRepo,
                id: id,
              ),
              child: SucursalScreen(id: id),
            ),
          );
        },
      ),
      GoRoute(
        path: '/telas',
        builder: (context, state) {
          return BlocProvider(
            create: (_) => TelasBloc(
              telasRepository: TelasRepositoryImpl(TelasDatasourceImpl()),
            ),
            child: const TelasScreen(),
          );
        },
      ),
      GoRoute(
        path: '/tela/:idtela',
        builder: (context, state) {
          final id = _pathParamInt(state, 'idtela');
          final telasRepo = TelasRepositoryImpl(TelasDatasourceImpl());
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => TelasBloc(telasRepository: telasRepo),
              ),
              BlocProvider(
                create: (_) => TelaBloc(
                  telasRepository: telasRepo,
                  id: id,
                ),
              ),
            ],
            child: TelaScreen(id: id),
          );
        },
      ),
      GoRoute(
        path: '/ventas/:idsucursal',
        builder: (context, state) {
          final idsucursal = _pathParamInt(state, 'idsucursal');
          return BlocProvider(
            create: (_) => VentasBloc(
              ventasRepository: VentasRepositoryImpl(VentasDatasourceImpl()),
              idsucursal: idsucursal,
            ),
            child: VentasScreen(idsucursal: idsucursal),
          );
        },
      ),
      GoRoute(
        path: '/det_ventas/:idventa',
        builder: (context, state) {
          final idventa = _pathParamInt(state, 'idventa');
          final ventasRepo = VentasRepositoryImpl(VentasDatasourceImpl());
          final detVentasRepo =
              DetalleVentasRepositoryImpl(DetalleVentasDatasourceImpl());
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => VentaBloc(
                  ventasRepository: ventasRepo,
                  id: idventa,
                ),
              ),
              BlocProvider(
                create: (ctx) => DetalleVentasBloc(
                  detalleVentasRepository: detVentasRepo,
                  updateVenta: ctx.read<VentaBloc>().actualizarVenta,
                  idventa: idventa,
                ),
              ),
            ],
            child: DetVentas(idventa: idventa),
          );
        },
      ),
      GoRoute(
        path: '/det_venta/:idsucursal',
        builder: (context, state) {
          final idsucursal = _pathParamInt(state, 'idsucursal');
          final ventasRepo = VentasRepositoryImpl(VentasDatasourceImpl());
          final detVentasRepo =
              DetalleVentasRepositoryImpl(DetalleVentasDatasourceImpl());
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => DetalleVentaFormCubit(
                  ventasRepository: ventasRepo,
                  detalleVentasRepository: detVentasRepo,
                  idsucursal: idsucursal,
                ),
              ),
              BlocProvider(
                create: (_) =>
                    TelasBloc(telasRepository: TelasRepositoryImpl(TelasDatasourceImpl())),
              ),
            ],
            child: DetVenta(),
          );
        },
      ),
    ],
  );
}
