import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/apliques/apliques.dart';
import 'package:textiles_app/features/apliques/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/colores/colores.dart';
import 'package:textiles_app/features/colores/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/colores/presentation/bloc/bloc.dart';
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
        path: '/venta-apliques',
        builder: (context, state) => const VentaApliquesSucursalesScreen(),
      ),
      GoRoute(
        path: '/venta-apliques/:idsucursal',
        builder: (context, state) {
          final idsucursal = _pathParamInt(state, 'idsucursal');
          final apliquesRepo =
              ApliquesRepositoryImpl(ApliquesDatasourceImpl());
          final ventasApliquesRepo = VentasApliquesRepositoryImpl(
              VentasApliquesDatasourceImpl());
          return MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => ApliquesBloc(
                  apliquesRepository: apliquesRepo,
                  idsucursal: idsucursal,
                ),
              ),
              BlocProvider(
                create: (_) => VentaApliquesFormCubit(
                  ventasApliquesRepository: ventasApliquesRepo,
                  idsucursal: idsucursal,
                ),
              ),
            ],
            child: VentaApliquesScreen(),
          );
        },
      ),
      GoRoute(
        path: '/fabricacion',
        builder: (context, state) => BlocProvider(
          create: (_) => ProduccionFormCubit(
            apliquesRepository:
                ApliquesRepositoryImpl(ApliquesDatasourceImpl()),
          ),
          child: ProduccionScreen(),
        ),
      ),
      GoRoute(
        path: '/apliques',
        builder: (context, state) => BlocProvider(
          create: (_) => ApliquesBloc(
            apliquesRepository:
                ApliquesRepositoryImpl(ApliquesDatasourceImpl()),
          ),
          child: const ApliquesScreen(),
        ),
      ),
      GoRoute(
        path: '/aplique/:idaplique',
        builder: (context, state) {
          final id = _pathParamInt(state, 'idaplique');
          return BlocProvider(
            create: (_) => ApliquesBloc(
              apliquesRepository:
                  ApliquesRepositoryImpl(ApliquesDatasourceImpl()),
            ),
            child: ApliqueScreen(id: id),
          );
        },
      ),
      GoRoute(
        path: '/aplique-colores/:idaplique',
        builder: (context, state) {
          final id = _pathParamInt(state, 'idaplique');
          return BlocProvider(
            create: (_) => ApliqueColoresCubit(
              apliquesRepository:
                  ApliquesRepositoryImpl(ApliquesDatasourceImpl()),
              idaplique: id,
            ),
            child: ApliqueColoresScreen(idaplique: id),
          );
        },
      ),
      GoRoute(
        path: '/colores',
        builder: (context, state) => BlocProvider(
          create: (_) => ColoresBloc(
            coloresRepository:
                ColoresRepositoryImpl(ColoresDatasourceImpl()),
          ),
          child: const ColoresScreen(),
        ),
      ),
      GoRoute(
        path: '/color/:idcolor',
        builder: (context, state) {
          final id = _pathParamInt(state, 'idcolor');
          return BlocProvider(
            create: (_) => ColoresBloc(
              coloresRepository:
                  ColoresRepositoryImpl(ColoresDatasourceImpl()),
            ),
            child: ColorScreen(id: id),
          );
        },
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
        path: '/sucursal-disponibilidad/:idsucursal',
        builder: (context, state) {
          final id = _pathParamInt(state, 'idsucursal');
          return BlocProvider(
            create: (_) => SucursalDisponibilidadCubit(
              sucursalesRepository:
                  SucursalesRepositoryImpl(SucursalesDatasourceImpl()),
              idsucursal: id,
            ),
            child: const SucursalDisponibilidadScreen(),
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
                    TelasBloc(telasRepository: TelasRepositoryImpl(TelasDatasourceImpl()), idsucursal: idsucursal),
              ),
            ],
            child: DetVenta(),
          );
        },
      ),
    ],
  );
}
