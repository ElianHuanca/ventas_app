@Tags(['benchmark'])
library;

// Micro-benchmarks de la regla de redirección por sesión del router
// (`redirect` de GoRouter): corre en cada navegación y cada vez que cambia
// la sesión.
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/auth/presentation/sesion_router.dart';

import 'medicion.dart';

/// Último resultado medido: que el compilador no pueda descartar el trabajo.
Object? sink;

/// `matchedLocation` de cada ruta registrada en `app_router.dart`, con
/// parámetros concretos.
const _rutas = [
  '/login',
  '/',
  '/venta-apliques',
  '/venta-apliques/3',
  '/venta-apliques/registro/3',
  '/venta-apliques/detalle/120',
  '/fabricacion',
  '/fabricacion/2',
  '/fabricacion/registro/2',
  '/fabricacion/detalle/45',
  '/sucursales',
  '/sucursal/1',
  '/sucursal-disponibilidad/1',
  '/telas',
  '/tela/17',
  '/tela-colores/17',
  '/apliques',
  '/aplique/8',
  '/aplique-colores/8',
  '/colores',
  '/color/4',
  '/ventas/1',
  '/det_ventas/250',
  '/det_venta/1',
  '/dashboard',
];

void main() {
  grupoBenchmark('router', () {
    microBenchmark(
      'redireccionPorSesion sin sesión en /login',
      () => sink = redireccionPorSesion(haySesion: false, ubicacion: '/login'),
      presupuestoUs: 0.1,
      preparar: () => expect(
          redireccionPorSesion(haySesion: false, ubicacion: '/login'), isNull),
    );
    microBenchmark(
      'redireccionPorSesion sin sesión en ruta protegida',
      () => sink = redireccionPorSesion(
          haySesion: false, ubicacion: '/venta-apliques/registro/3'),
      presupuestoUs: 0.1,
      preparar: () => expect(
          redireccionPorSesion(
              haySesion: false, ubicacion: '/venta-apliques/registro/3'),
          rutaLogin),
    );
    microBenchmark(
      'redireccionPorSesion con sesión en /login',
      () => sink = redireccionPorSesion(haySesion: true, ubicacion: '/login'),
      presupuestoUs: 0.1,
      preparar: () => expect(
          redireccionPorSesion(haySesion: true, ubicacion: '/login'), '/'),
    );
    microBenchmark(
      'redireccionPorSesion con sesión en ruta protegida',
      () =>
          sink = redireccionPorSesion(haySesion: true, ubicacion: '/dashboard'),
      presupuestoUs: 0.1,
      preparar: () => expect(
          redireccionPorSesion(haySesion: true, ubicacion: '/dashboard'),
          isNull),
    );
    microBenchmark(
      'redireccionPorSesion sin sesión x${_rutas.length} rutas',
      () {
        for (final ruta in _rutas) {
          sink = redireccionPorSesion(haySesion: false, ubicacion: ruta);
        }
      },
      presupuestoUs: 5,
      preparar: () {
        for (final ruta in _rutas) {
          expect(redireccionPorSesion(haySesion: false, ubicacion: ruta),
              ruta == rutaLogin ? isNull : rutaLogin);
        }
      },
    );
    microBenchmark(
      'redireccionPorSesion con sesión x${_rutas.length} rutas',
      () {
        for (final ruta in _rutas) {
          sink = redireccionPorSesion(haySesion: true, ubicacion: ruta);
        }
      },
      presupuestoUs: 5,
      preparar: () {
        for (final ruta in _rutas) {
          expect(redireccionPorSesion(haySesion: true, ubicacion: ruta),
              ruta == rutaLogin ? '/' : isNull);
        }
      },
    );
  });
}
