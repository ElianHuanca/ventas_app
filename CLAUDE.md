# Textiles App — Claude Code Guide

## Project Overview

Flutter mobile/desktop/web application for managing textile sales. Features branch management (sucursales), fabric catalog (telas), sales transactions (ventas), and a sales dashboard.

> **La app usa SQLite exclusivamente — no consume ninguna API REST.** `dio`, `google_fonts`, `shared_preferences`, `formz`, `cupertino_icons` y `flutter_dotenv` fueron eliminados del proyecto.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart ≥3.0.6) |
| State Management | BLoC pattern (`flutter_bloc` v8.1.6) |
| Navigation | `go_router` v13.1.0 |
| Local DB | SQLite (`sqflite` v2.3.0) |
| Path utils | `path` |
| UI | Material 3 |

## Architecture

Clean Architecture con módulos por feature en `lib/features/`:

```
feature/
  domain/         # Entities, abstract repos & datasources
  infrastructure/ # Repo impls, datasource impls, mappers
  presentation/   # Screens, BLoCs/Cubits, form providers
```

Features: `sucursales`, `telas`, `ventas`, `dashboard`, `shared`, `database`

## Database Schema (SQLite, v2)

| Table | Key Columns |
|-------|-------------|
| sucursales | id, nombre |
| telas | id, nombre, precxmen, precxmay, precxrollo, precxcompra, idusuarios |
| ventas | id, fecha, total, ganancias, descuento, idsucursales |
| detalle_ventas | id, nombre, precio, cantidad, total, ganancias, idtelas, idventa |

Schema gestionado en `lib/features/database/database_helper.dart`. Incrementar `_databaseVersion` y agregar un caso en `_onUpgrade` al cambiar el esquema.

### Convención importante: `actualizarVenta`

`VentasDatasourceImpl.actualizarVenta` usa **aritmética SQL incremental** (`total = total + ?`), no un SET directo. Siempre pasar **deltas** (no valores absolutos) desde los BLoCs al llamar a este método.

## Key Files

- `lib/main.dart` — Entry point, BLoC providers setup
- `lib/config/router/app_router.dart` — Todas las rutas (GoRouter + BLoC providers por ruta)
- `lib/config/theme/app_theme.dart` — Material 3 theme
- `lib/features/database/database_helper.dart` — SQLite init & migraciones
- `lib/features/ventas/infrastructure/datasources/ventas_datasource_impl.dart` — lógica incremental de ventas
- `lib/features/ventas/infrastructure/datasources/detalleVentas_datasource_impl.dart` — upsert por idtelas+precio al crear detalles

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

Solo 5 dependencias declaradas en `pubspec.yaml`:
- `flutter_bloc` — estado
- `go_router` — navegación
- `sqflite` — base de datos local
- `path` — rutas de archivo (usado en `database_helper.dart`)
- `flutter_lints` (dev) — linting
