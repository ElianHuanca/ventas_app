# CLAUDE.md

Guía para Claude Code (claude.ai/code) al trabajar en este repositorio.

## Overview

App **Flutter** (móvil / desktop / web) de punto de venta de **telas** para el negocio Huantex. Gestiona sucursales, catálogo de telas, ventas con su detalle, y un dashboard de ventas. Todo el texto está en español.

> El paquete se llama `textiles_app` en `pubspec.yaml` y los imports son `package:textiles_app/...`. **No confundir con el repo `textiles`**, que es la app PHP de apliques (ver abajo). Este repo es `ventas_app` = telas.

> **Backend: Supabase (PostgreSQL).** Antes usaba SQLite (`sqflite`), que fue eliminado — `lib/features/database/` quedó vacío. La conexión se inicializa en `main.dart` vía `SupabaseConfig.init()` y los datasources acceden con `SupabaseConfig.client`.

## Los tres repos comparten UNA base de datos

Una sola DB Postgres en Supabase alimenta tres aplicaciones:

| Repo | Stack | Rol |
|---|---|---|
| **ventas_app** (este) | Flutter | Punto de venta de **telas**. Dueño del esquema → `github.com/ElianHuanca/ventas_app` |
| **textiles** | PHP 8.2 MVC | Inventario, compras, gastos y ventas de **apliques** → `github.com/ElianHuanca/textiles` |
| **sitio** | Next.js 16 | Landing pública de solo lectura → `github.com/ElianHuanca/sitio` |

En disco son carpetas hermanas (`f:\Elian\ventas_app`, `f:\Elian\textiles`, `f:\Elian\sitio`).

**Este repo es el dueño del esquema.** `supabase/` es la fuente de verdad para las otras dos apps:

- **`supabase/schema.sql`** — tablas, índices, RLS, seed de telas y las funciones RPC del dashboard.
- **`supabase/landing.sql`** — las vistas públicas que consume la web (`sitio`). Se aplica **después** de `schema.sql`.

Al cambiar el esquema: editar el archivo y volver a aplicarlo en el SQL Editor de Supabase. **Antes de renombrar o borrar una columna, revisar si `textiles` o `sitio` la usan.**

### ⚠️ Tablas compartidas: cuidado al tocarlas

- **`ventas` es compartida** entre este repo (telas) y `textiles` (apliques). La columna **`origen`** (`'telas'` / `'apliques'`) las separa; la agregó la migración `textiles/migracion/04_origen_ventas.sql`, por eso **no aparece en `schema.sql`**.
  **Esta app todavía no la usa**: `VentasDatasourceImpl` ni la setea al crear ni filtra por ella al leer. Consecuencias conocidas: `getVentas()` puede traer ventas de apliques de la misma sucursal, y `getVentaByFecha()` usa `.maybeSingle()`, que revienta si ese día hay una venta de telas y una de apliques. Si se toca ese datasource, lo correcto es setear `origen: 'telas'` en `createVenta` y agregar `.eq('origen', 'telas')` en las lecturas.
- **`sucursales`** también la lee `textiles`, y sus columnas `activo`, `direccion`, `latitud`, `longitud` y `slug` las publica la landing. Para dar de baja una sucursal, marcar `activo = false` en vez de borrarla.
- `categorias` y `colores` son compartidas con `textiles` (que las usa para apliques).

## Tech Stack

| Capa | Tecnología |
|---|---|
| Framework | Flutter (Dart ≥3.0.6) |
| Estado | BLoC (`flutter_bloc` ^8.1.6) |
| Navegación | `go_router` ^13.1.0 |
| Backend / DB | Supabase — PostgreSQL (`supabase_flutter` ^2.8.0) |
| i18n | `flutter_localizations` |
| Lint | `flutter_lints` (dev) |
| UI | Material 3 |

## Arquitectura

Clean Architecture con módulos por feature en `lib/features/`:

```
feature/
  domain/         # Entities, repos y datasources abstractos
  infrastructure/ # Impls de repos y datasources, mappers
  presentation/   # Screens, BLoCs/Cubits, form providers
```

Features: `sucursales`, `telas`, `ventas`, `dashboard`, `shared`

## Esquema (Supabase / PostgreSQL)

| Tabla | Columnas clave |
|---|---|
| `sucursales` | id, nombre, slug, direccion, latitud, longitud, activo |
| `telas` | id, nombre, precxmen, precxmay, precxrollo, precxcompra, categoria_id, slug, descripcion, ancho, activo |
| `ventas` | id, fecha, total, ganancias, descuento, idsucursales (+ `origen`, ver arriba) |
| `detalle_ventas` | id, nombre, precio, cantidad, total, ganancias, idtelas, idventa |
| `categorias` | id, nombre, slug, activo — seed: `Telas`, `Apliques` |
| `colores` | id, nombre, hex, activo |
| `tela_colores` | idtela, idcolor, activo (PK compuesta) |
| `tela_fotos` | id, idtela, url, activo |

`fecha` se almacena como **TEXT ISO8601** (igual que en la versión SQLite) para preservar la lógica de comparación — las RPC comparan lexicográficamente y eso depende de este formato. Los precios son `NUMERIC` (no `REAL`) para evitar errores de coma flotante en dinero.

Las tablas nuevas (`categorias`, `colores`, `tela_colores`, `tela_fotos`) y las columnas agregadas a `telas`/`sucursales` existen para el catálogo web; **esta app todavía no las lee ni las escribe**.

### Convención importante: `actualizarVenta`

`VentasDatasourceImpl.actualizarVenta` mantiene la convención **incremental**: lee el valor actual y le suma el delta (`total = total + delta`), excepto `fecha` que se asigna directa. Siempre pasar **deltas** (no valores absolutos) desde los BLoCs.

## Vistas públicas (`supabase/landing.sql`)

Las consume la landing Next.js. Existen para no exponer datos sensibles:

- **`top_telas_web`** — top 6 telas por `SUM(detalle_ventas.total)` histórico. Publica `posicion`, **no el monto**, y nunca `precxcompra`. Agrupa por `idtelas` (no por `nombre`) para que renombrar una tela no parta su historial. Aplica `NULLIF(precio, 0)`: **precio 0 = no se vende en esa modalidad**.
- **`sucursales_web`** — sucursales con `activo = true`.

Ambas con `GRANT SELECT ... TO anon`. Si se cambia una columna que estas vistas leen, hay que volver a aplicar `landing.sql`.

## Archivos clave

- `lib/main.dart` — entry point, init de Supabase + BLoC providers
- `lib/config/supabase/supabase_config.dart` — credenciales e init del cliente
- `supabase/schema.sql` — esquema PostgreSQL, RLS, seed y RPC
- `supabase/landing.sql` — vistas públicas de la landing
- `lib/config/router/app_router.dart` — todas las rutas (GoRouter + BLoC providers por ruta)
- `lib/config/theme/app_theme.dart` — tema Material 3
- `lib/features/ventas/infrastructure/datasources/ventas_datasource_impl.dart` — lógica incremental de ventas
- `lib/features/ventas/infrastructure/datasources/detalleVentas_datasource_impl.dart` — upsert por idtelas+precio al crear detalles
- `lib/features/dashboard/infrastructure/datasources/dashboard_datasource_impl.dart` — llama a las RPC del dashboard

## Rutas registradas

| Path | Screen |
|---|---|
| `/` | SucursalesScreen (ventas) |
| `/sucursales` | SucursalesScreen (gestión) |
| `/sucursal/:idsucursal` | SucursalScreen |
| `/telas` | TelasScreen |
| `/tela/:idtela` | TelaScreen |
| `/ventas/:idsucursal` | VentasScreen |
| `/det_ventas/:idventa` | DetVentas |
| `/det_venta/:idventa` | DetVenta (formulario de registro) |
| `/dashboard` | DashboardScreen |

## Convenciones de estado

- **BLoC** para estado de features (listas, CRUD)
- **Cubit** para estado de formularios
- Los BLoC providers se crean a nivel de ruta en `app_router.dart`
- `DetalleVentaFormCubit` acumula items en memoria antes del submit; si se añade el mismo producto al mismo precio **suma la cantidad** en vez de crear un item nuevo
- Al hacer submit, `createDetalleVenta` hace **upsert** (busca por `idventa + idtelas + precio`; si existe suma, si no inserta)

## Dashboard

- Ruta: `/dashboard`
- Muestra todos los productos ordenados por total vendido (DESC) en un rango de fechas
- Rango default: primer día del mes actual → hoy; el selector usa `showDateRangePicker`
- Usa las RPC `top_productos(desde, hasta)` y `resumen_ventas(desde, hasta)` porque el cliente de Supabase no permite `GROUP BY`/`SUM` directo. Ambas son `LANGUAGE sql STABLE` y comparan `fecha` como texto ISO8601.

## Supabase

- Credenciales e init en `lib/config/supabase/supabase_config.dart`; `SupabaseConfig.client` es el cliente compartido por todos los datasources.
- Las tablas tienen RLS habilitado con **políticas abiertas** (app de un solo usuario, sin login). Si se agrega Supabase Auth, restringir las políticas en `supabase/schema.sql`.

## Comandos

```bash
flutter pub get          # instalar dependencias
flutter run              # correr en debug
flutter build apk        # build Android APK
flutter analyze          # lint check
flutter clean            # limpiar build
```

No hay tests más allá del `test/` por defecto de Flutter.

## Notas Windows / Android

Si aparece `this and base files have different roots` en Gradle (común cuando el proyecto está en `F:`/`D:` y el pub cache en `C:`):

```bash
flutter clean
cd android && ./gradlew clean
flutter pub get
```
