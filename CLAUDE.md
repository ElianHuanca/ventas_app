# Textiles App — Claude Code Guide

## Project Overview

Flutter mobile/desktop/web application for managing textile sales. Features branch management (sucursales), fabric catalog (telas), sales transactions (ventas), and a sales dashboard.

> **La app usa Supabase (PostgreSQL) como backend.** Antes usaba SQLite (`sqflite`), que fue eliminado. La conexión se inicializa en `main.dart` vía `SupabaseConfig.init()` y los datasources acceden con `SupabaseConfig.client`. El esquema y las funciones RPC del dashboard están en `supabase/schema.sql`.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart ≥3.0.6) |
| State Management | BLoC pattern (`flutter_bloc` v8.1.6) |
| Navigation | `go_router` v13.1.0 |
| Backend / DB | Supabase — PostgreSQL (`supabase_flutter` v2.8) |
| UI | Material 3 |

## Architecture

Clean Architecture con módulos por feature en `lib/features/`:

```
feature/
  domain/         # Entities, abstract repos & datasources
  infrastructure/ # Repo impls, datasource impls, mappers
  presentation/   # Screens, BLoCs/Cubits, form providers
```

Features: `sucursales`, `telas`, `ventas`, `dashboard`, `shared`

## Database Schema (Supabase / PostgreSQL)

| Table | Key Columns |
|-------|-------------|
| sucursales | id, nombre |
| telas | id, nombre, precxmen, precxmay, precxrollo, precxcompra |
| ventas | id, fecha, total, ganancias, descuento, idsucursales |
| detalle_ventas | id, nombre, precio, cantidad, total, ganancias, idtelas, idventa |

Schema definido en `supabase/schema.sql` (tablas, índices, RLS, seed de telas y funciones RPC `top_productos` / `resumen_ventas`). Al cambiar el esquema, editar ese archivo y volver a aplicarlo en Supabase. `fecha` se almacena como TEXT ISO8601 (igual que en la versión SQLite) para preservar la lógica de comparación.

### Convención importante: `actualizarVenta`

`VentasDatasourceImpl.actualizarVenta` mantiene la convención **incremental**: lee el valor actual y le suma el delta (`total = total + delta`), excepto `fecha` que se asigna directa. Siempre pasar **deltas** (no valores absolutos) desde los BLoCs.

## Key Files

- `lib/main.dart` — Entry point, init de Supabase + BLoC providers
- `lib/config/supabase/supabase_config.dart` — credenciales e init del cliente Supabase
- `supabase/schema.sql` — esquema PostgreSQL, RLS, seed y funciones RPC
- `lib/config/router/app_router.dart` — Todas las rutas (GoRouter + BLoC providers por ruta)
- `lib/config/theme/app_theme.dart` — Material 3 theme
- `lib/features/ventas/infrastructure/datasources/ventas_datasource_impl.dart` — lógica incremental de ventas
- `lib/features/ventas/infrastructure/datasources/detalleVentas_datasource_impl.dart` — upsert por idtelas+precio al crear detalles
- `lib/features/dashboard/infrastructure/datasources/dashboard_datasource_impl.dart` — llama a las RPC del dashboard

## Rutas registradas

| Path | Screen |
|------|--------|
| `/` | SucursalesScreen (ventas) |
| `/sucursales` | SucursalesScreen (gestión) |
| `/sucursal/:idsucursal` | SucursalScreen |
| `/telas` | TelasScreen |
| `/tela/:idtela` | TelaScreen |
| `/ventas/:idsucursal` | VentasScreen |
| `/det_ventas/:idventa` | DetVentas |
| `/det_venta/:idventa` | DetVenta (formulario de registro) |
| `/dashboard` | DashboardScreen |

## State Management Conventions

- **BLoC** para estado de features (listas, CRUD)
- **Cubit** para estado de formularios
- BLoC providers se crean a nivel de ruta en `app_router.dart`
- `DetalleVentaFormCubit` acumula items en memoria antes del submit; si se añade el mismo producto al mismo precio **suma la cantidad** en vez de crear un nuevo item
- Al hacer submit, `createDetalleVenta` en el datasource hace **upsert** (busca por `idventa + idtelas + precio`; si existe suma, si no inserta)

## Dashboard

- Ruta: `/dashboard`
- Muestra todos los productos ordenados por total vendido (DESC) en un rango de fechas
- Rango default: primer día del mes actual → hoy
- El selector de período usa `showDateRangePicker`
- Query SQL: `GROUP BY dv.nombre` sobre `detalle_ventas JOIN ventas` filtrando por `v.fecha`

## Common Commands

```bash
flutter pub get          # Instalar dependencias
flutter run              # Correr en debug
flutter build apk        # Build Android APK
flutter analyze          # Lint check
flutter clean            # Limpiar build (necesario si hay error de rutas Gradle en Windows multi-disco)
```

## Notas Windows / Android

Si aparece el error `this and base files have different roots` en Gradle (común cuando el proyecto está en D: y el pub cache en C:), ejecutar:
```bash
flutter clean
cd android && ./gradlew clean
flutter pub get
```

## Dependencias activas

Dependencias declaradas en `pubspec.yaml`:
- `flutter_bloc` — estado
- `go_router` — navegación
- `supabase_flutter` — backend / base de datos (PostgreSQL)
- `flutter_localizations` — i18n
- `flutter_lints` (dev) — linting

## Supabase

- Credenciales y init en `lib/config/supabase/supabase_config.dart`.
- `SupabaseConfig.client` es el cliente compartido por todos los datasources.
- Las tablas tienen RLS habilitado con políticas abiertas (app de un solo usuario, sin login). Si se agrega Supabase Auth, restringir las políticas en `supabase/schema.sql`.
- El dashboard usa funciones RPC (`top_productos`, `resumen_ventas`) porque el cliente no permite GROUP BY/SUM directo.
