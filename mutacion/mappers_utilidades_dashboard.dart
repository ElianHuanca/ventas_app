// Comando de test de mappers_utilidades_dashboard.xml.
//
// mutation_test corre el mismo comando para cada mutante, sin decirle qué
// archivo mutó. Este script lo averigua con `git diff` (el único cambio en lib/
// es el del mutante) y corre solo los tests de ese archivo: ~12 s por mutante
// en vez de ~35 s con todos juntos.
//
// Sin cambios en lib/ (o con un archivo que no está en la tabla) corre todos
// los de la tabla. Se puede probar a mano: `dart mutacion/mappers_utilidades_dashboard.dart`.
import 'dart:io';

/// Archivo de lib/ → tests que lo ejercitan.
const _testsPorArchivo = <String, List<String>>{
  // Mappers
  'lib/features/apliques/infrastructure/mappers/aplique_mapper.dart': [
    'test/features/apliques/infrastructure/mappers',
  ],
  'lib/features/apliques/infrastructure/mappers/produccion_mapper.dart': [
    'test/features/apliques/infrastructure/mappers',
  ],
  'lib/features/apliques/infrastructure/mappers/stock_aplique_mapper.dart': [
    'test/features/apliques/infrastructure/mappers',
  ],
  'lib/features/apliques/infrastructure/mappers/venta_aplique_mapper.dart': [
    'test/features/apliques/infrastructure/mappers',
  ],
  'lib/features/sucursales/infrastructure/mappers/sucursal_mapper.dart': [
    'test/features/sucursales/infrastructure/mappers',
  ],
  'lib/features/sucursales/infrastructure/mappers/tela_sucursal_mapper.dart': [
    'test/features/sucursales/infrastructure/mappers',
  ],
  'lib/features/telas/infrastructure/mappers/tela_mapper.dart': [
    'test/features/telas/infrastructure/mappers',
  ],
  'lib/features/ventas/infrastructure/mappers/detalleVenta_mapper.dart': [
    'test/features/ventas/infrastructure/mappers',
    'test/features/ventas/domain',
  ],
  'lib/features/ventas/infrastructure/mappers/venta_mapper.dart': [
    'test/features/ventas/infrastructure/mappers',
  ],

  // Utilidades
  'lib/features/shared/changeFormatDate.dart': [
    'test/features/shared/utils_test.dart',
  ],
  'lib/features/shared/widgets/color_from_hex.dart': [
    'test/features/shared/utils_test.dart',
  ],

  // Dashboard
  'lib/features/dashboard/presentation/bloc/dashboard_cubit.dart': [
    'test/features/dashboard/presentation',
    'test/features/dashboard/dashboard_test.dart',
  ],

  // Entidades
  'lib/features/apliques/domain/entities/aplique.dart': [
    'test/features/apliques/presentation/bloc/aplique_form_cubit_test.dart',
  ],
  'lib/features/sucursales/domain/entities/sucursal.dart': [
    'test/features/sucursales/domain',
    'test/features/sucursales/presentation/bloc/sucursal_form_cubit_test.dart',
  ],
  'lib/features/sucursales/domain/entities/tela_sucursal.dart': [
    'test/features/sucursales/domain',
  ],
  'lib/features/telas/domain/entities/tela.dart': [
    'test/features/telas/presentation/bloc/tela_form_cubit_test.dart',
  ],
  'lib/features/ventas/domain/entities/detalleVenta.dart': [
    'test/features/ventas/domain',
  ],

  // Repositorios
  'lib/features/apliques/infrastructure/repositories/apliques_repository_impl.dart':
      [
    'test/features/apliques/infrastructure/repositories/apliques_repository_impl_test.dart',
  ],
  'lib/features/apliques/infrastructure/repositories/ventas_apliques_repository_impl.dart':
      [
    'test/features/apliques/infrastructure/repositories/ventas_apliques_repository_impl_test.dart',
  ],
  'lib/features/colores/infrastructure/repositories/colores_repository_impl.dart':
      [
    'test/features/colores/infrastructure/repositories',
  ],
  'lib/features/dashboard/infrastructure/repositories/dashboard_repository_impl.dart':
      [
    'test/features/dashboard/infrastructure/repositories',
  ],
  'lib/features/sucursales/infrastructure/repositories/sucursales_repository_impl.dart':
      [
    'test/features/sucursales/infrastructure/repositories',
  ],
  'lib/features/telas/infrastructure/repositories/telas_repository_impl.dart': [
    'test/features/telas/infrastructure/repositories',
  ],
  'lib/features/ventas/infrastructure/repositories/detalleVentas_repository_impl.dart':
      [
    'test/features/ventas/infrastructure/repositories/detalle_ventas_repository_impl_test.dart',
  ],
  'lib/features/ventas/infrastructure/repositories/ventas_repository_impl.dart':
      [
    'test/features/ventas/infrastructure/repositories/ventas_repository_impl_test.dart',
  ],
  'lib/features/auth/infrastructure/repositories/auth_repository_impl.dart': [
    'test/features/auth/auth_test.dart',
  ],
};

Future<void> main() async {
  final diff = await Process.run('git', ['diff', '--name-only', '--', 'lib']);
  final cambiados = (diff.stdout as String)
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty);

  final tests = <String>{
    for (final archivo in cambiados) ...?_testsPorArchivo[archivo],
  };
  if (tests.isEmpty) {
    tests.addAll(_testsPorArchivo.values.expand((t) => t));
  }
  // Una carpeta de la tabla que todavía no existe haría fallar el comando
  // (y el mutante contaría como detectado sin que ningún test lo vea).
  tests.removeWhere((t) => !File(t).existsSync() && !Directory(t).existsSync());

  final flutter = await Process.start(
    'flutter',
    ['test', '--no-pub', '--concurrency=1', ...tests],
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  exit(await flutter.exitCode);
}
