# Textiles App — Claude Code Guide

## Project Overview

Flutter mobile/desktop/web application for managing textile sales. Features branch management (sucursales), fabric catalog (telas), and sales transactions (ventas).

- **Backend API**: `https://textilesbackend-production.up.railway.app/api`
- **Local dev API**: `http://192.168.100.80:8000/api` (set via `.env`)

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart ≥3.0.6) |
| State Management | BLoC pattern (`flutter_bloc` v8.1.6) |
| Navigation | `go_router` v13.1.0 |
| HTTP Client | `dio` v5.4.1 |
| Local DB | SQLite (`sqflite` v2.3.0) |
| Local Storage | `shared_preferences` |
| Form Validation | `formz` v0.7.0 |
| UI | Material 3 |

## Architecture

Clean Architecture with feature-based modules under `lib/features/`:

```
feature/
  domain/         # Entities, abstract repos & datasources
  infrastructure/ # Repo impls, datasource impls, mappers
  presentation/   # Screens, BLoCs/Cubits, form providers
```

Features: `sucursales`, `telas`, `ventas`, `shared`, `database`

## Database Schema (SQLite, v2)

| Table | Key Columns |
|-------|-------------|
| sucursales | id, nombre |
| telas | id, nombre, precxmen, precxmay, precxrollo, precxcompra, idusuarios |
| ventas | id, fecha, total, ganancias, descuento, idsucursales |
| detalle_ventas | id, nombre, precio, cantidad, total, ganancias, idtelas, idventa |

Schema managed in `lib/features/database/database_helper.dart`. Bump `_databaseVersion` and add a migration case when changing schema.

## Key Files

- `lib/main.dart` — App entry point, BLoC providers setup
- `lib/config/router/app_router.dart` — All routes (GoRouter)
- `lib/config/theme/app_theme.dart` — Material 3 theme
- `lib/config/constants/environment.dart` — Env var loader (`.env`)
- `lib/features/database/database_helper.dart` — SQLite init & migrations

## Common Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run in debug mode
flutter build apk        # Build Android APK
flutter analyze          # Lint check
flutter test             # Run tests
```

## Environment Setup

Copy `.env.template` to `.env` and set `API_URL` before running.

## State Management Conventions

- **BLoC** for feature-level state (list views, CRUD operations)
- **Cubit** for form state (uses `formz` validators in `lib/features/shared/infrastructure/inputs/`)
- Route-level BLoC providers defined in `app_router.dart`
