import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/config/config.dart';
import 'package:textiles_app/features/auth/auth.dart';
import 'package:textiles_app/features/shared/widgets/menu_index_cubit.dart';
import 'package:textiles_app/features/sucursales/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseConfig.init();

  SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent));

  runApp(const HuantexApp());
}

/// La app completa con sus providers globales, sin inicializar Supabase.
/// Separada de `main()` para que los tests de integración (`integration_test/`)
/// la monten varias veces con un único `SupabaseConfig.init()`.
class HuantexApp extends StatelessWidget {
  const HuantexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        RepositoryProvider<AuthRepository>(create: (_) => AuthRepositoryImpl()),
        BlocProvider(create: (_) => MenuIndexCubit()),
        BlocProvider(
          create: (_) => SucursalesBloc(
            sucursalesRepository: SucursalesRepositoryImpl(
              SucursalesDatasourceImpl(),
            ),
          ),
        ),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??=
        createAppRouter(authRepository: context.read<AuthRepository>());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router!,
      theme: AppTheme().getTheme(),
      debugShowCheckedModeBanner: false,
      // Cinta "LOCAL" para no confundir la base de pruebas con producción.
      builder: SupabaseConfig.isLocal
          ? (context, child) => Banner(
                message: 'LOCAL',
                location: BannerLocation.topEnd,
                color: Colors.green.shade700,
                child: child!,
              )
          : null,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
    );
  }
}
