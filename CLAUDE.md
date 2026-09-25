# CLAUDE.md

Guía para Claude Code (claude.ai/code) al trabajar en este repositorio.

## Overview

App **Flutter** (móvil / desktop / web) de punto de venta de **telas y apliques** para el negocio Huantex. Gestiona sucursales, catálogo de telas, apliques (con stock por color y fabricación), ventas de ambos con su detalle, y un dashboard de ventas. Todo el texto está en español.

> Desde la incorporación del feature `apliques/` (ventas con stock, fabricación, gestión y disponibilidad por sucursal), esta app **reemplazó al repo PHP `textiles`**, que se borró de GitHub. ⚠️ La única copia que queda es la carpeta local `F:\Elian\textiles` (no existe respaldo en `notas/historico/`).

> El paquete se llama `textiles_app` en `pubspec.yaml` y los imports son `package:textiles_app/...`. **No confundir con el viejo repo `textiles`** (PHP, eliminado). Este repo es `ventas_app` = telas y apliques.

> **Backend: Supabase (PostgreSQL).** Antes usaba SQLite (`sqflite`), que fue eliminado — `lib/features/database/` quedó vacío. La conexión se inicializa en `main.dart` vía `SupabaseConfig.init()` y los datasources acceden con `SupabaseConfig.client`.

## Conocimiento compartido → vault de notas

Lo que cruza los tres repos —el contrato de la DB compartida, el registro de migraciones, las
decisiones y su porqué, los riesgos abiertos y los runbooks— **no vive acá**: vive en un vault de
Obsidian en `F:\Elian\notas`. Entrada: `MAPA.md`.

Este archivo manda sobre el código de **este** repo. El vault manda sobre lo que es de más de uno.
No duplicar: enlazar.

Como este repo es (parcialmente) dueño del esquema, antes de tocar `supabase/`:

- `../notas/runbooks/cambiar-el-esquema.md` — el procedimiento, incluido a quién avisar
- `../notas/datos/migraciones/registro-de-migraciones.md` — qué se aplicó y en qué orden
- `../notas/pendientes/schema-sql-desactualizado.md` — ⚠️ **`schema.sql` ya no describe la producción**

Esta app ahora también cubre **apliques** (ventas con stock, fabricación, gestión y disponibilidad por sucursal), con lo que **reemplazó al repo PHP `textiles`** (eliminado).

## Los repos comparten UNA base de datos

Una sola DB Postgres en Supabase alimenta estas aplicaciones:

| Repo | Stack | Rol |
|---|---|---|
| **ventas_app** (este) | Flutter | Punto de venta de **telas y apliques**. Dueño del esquema → `github.com/ElianHuanca/ventas_app` |
| ~~**textiles**~~ | PHP 8.2 MVC | **Eliminado** de GitHub; queda solo la carpeta local `F:\Elian\textiles`. Era el módulo de apliques; lo absorbió este repo |
| **sitio** | Next.js 16 | Landing pública de solo lectura → `github.com/ElianHuanca/sitio` |
| **ventas_app_android** | Kotlin + Compose | Port nativo Android (por ahora solo telas: sucursales, telas, ventas, dashboard) → `github.com/ElianHuanca/ventas_app_android` (privado). Su build type `local` usa el mismo Supabase de Docker que este repo (ver "Entorno local") |

En disco son carpetas hermanas (`F:\Elian\ventas_app`, `F:\Elian\ventas_app_android`, `F:\Elian\sitio`); el vault de notas está en `F:\Elian\notas`.

**Este repo es el dueño del esquema.** `supabase/` es la fuente de verdad para las otras dos apps:

- **`supabase/schema.sql`** — tablas, índices, RLS, seed de telas y las funciones RPC del dashboard.
- **`supabase/landing.sql`** — las vistas públicas que consume la web (`sitio`). Se aplica **después** de `schema.sql`.

Al cambiar el esquema: editar el archivo y volver a aplicarlo en el SQL Editor de Supabase. **Antes de renombrar o borrar una columna, revisar si `sitio` o `ventas_app_android` la usan.**

### ⚠️ Tablas compartidas: cuidado al tocarlas

- **`ventas` es SOLO telas** desde la migración `supabase/ventas_apliques.sql` (10): las ventas de apliques viven en **`ventas_apliques`** (misma forma, sin `origen`; `detalle_ventas_apliques.idventa` apunta ahí). El discriminador `origen` ya no existe. El PHP `textiles` (obsoleto) filtraba por `origen` y quedó roto con esta migración.
- **`sucursales`** también la lee `textiles`, y sus columnas `activo`, `direccion`, `latitud`, `longitud` y `slug` las publica la landing. Para dar de baja una sucursal, marcar `activo = false` en vez de borrarla.
- `categorias` y `colores` son compartidas con `textiles` (que las usa para apliques).
- **`tela_sucursales`** (migración `supabase/tela_sucursales.sql`) define qué telas se venden en qué sucursal. La venta de telas filtra su selector por ella: si la sucursal tiene vínculos activos solo ofrece esas telas; si no tiene ninguno configurado, muestra todo el catálogo (regla de transición).
- **`inventario`** (sucursal+aplique+color) es la disponibilidad Y el stock de apliques. La venta de apliques lo descuenta y bloquea sobre-stock; Fabricación lo incrementa (y crea la fila si no existe). Las filas se dan de baja con `activo = false` (solo si stock = 0, desde el datasource `removeInventario`).

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

Features: `sucursales`, `telas`, `ventas`, `apliques`, `colores`, `dashboard`, `shared`

## Esquema (Supabase / PostgreSQL)

| Tabla | Columnas clave |
|---|---|
| `sucursales` | id, nombre, slug, direccion, latitud, longitud, activo |
| `telas` | id, nombre, precxmen, precxmay, precxrollo, precxcompra, categoria_id, slug, descripcion, ancho, activo |
| `ventas` | id, fecha, total, ganancias, descuento, idsucursales — **solo telas** |
| `ventas_apliques` | id, fecha, total, ganancias, descuento, idsucursales — **solo apliques** (migración 10) |
| `detalle_ventas` | id, nombre, precio, cantidad, total, ganancias, idtelas, idventa |
| `categorias` | id, nombre, slug, activo — seed: `Telas`, `Apliques` |
| `colores` | id, nombre, hex, activo |
| `tela_colores` | idtela, idcolor, activo (PK compuesta) |
| `tela_fotos` | id, idtela, url, activo |
| `tela_sucursales` | idtela, idsucursal, activo (PK compuesta) — disponibilidad de telas por sucursal (migración `supabase/tela_sucursales.sql`) |
| `apliques` | id, nombre, costo_fabricacion, ancho_cm, alto_cm, categoria_id, activo (tamanio quedó sin uso: ya va en el nombre) |
| `inventario` | sucursal_id, aplique_id, color_id, stock (PK compuesta) — disponibilidad y stock de apliques |
| `producciones` | id, fecha (date), sucursal_id — **cabecera** de fabricación: una fila por sucursal+día (migración `supabase/detalle_produccion.sql`) |
| `detalle_produccion` | id, idproduccion, idaplique, idcolor, cantidad — líneas de la fabricación del día; sube el stock de `inventario` |
| `detalle_ventas_apliques` | id, idventa, idapliques, idcolor, nombre, precio, cantidad, total, ganancias |

`fecha` se almacena como **TEXT ISO8601** (igual que en la versión SQLite) para preservar la lógica de comparación — las RPC comparan lexicográficamente y eso depende de este formato. Los precios son `NUMERIC` (no `REAL`) para evitar errores de coma flotante en dinero.

Las tablas nuevas (`categorias`, `colores`, `tela_colores`, `tela_fotos`) y las columnas agregadas a `telas`/`sucursales` existen para el catálogo web; esta app gestiona `colores` (módulo `/colores`, baja lógica) pero **no escribe** `tela_colores`/`tela_fotos` (solo `tela_colores` en la gestión de colores por tela).

### Convención importante: `actualizarVenta`

`VentasDatasourceImpl.actualizarVenta` mantiene la convención **incremental**: lee el valor actual y le suma el delta (`total = total + delta`), excepto `fecha` que se asigna directa. Siempre pasar **deltas** (no valores absolutos) desde los BLoCs.

### Convención importante: fabricación (`producciones` / `detalle_produccion`)

`ApliquesDatasourceImpl.createProduccion` sigue el mismo patrón cabecera+detalle que ventas:

1. Busca la `producción` (cabecera) de esa sucursal con `fecha = hoy`; si no existe, la crea (equivalente a `getVentaByFecha` + `createVenta`).
2. Hace **upsert** en `detalle_produccion` por `(idproduccion, idaplique, idcolor)`: si ya se fabricó ese aplique+color hoy, suma la cantidad a la línea existente; si no, inserta una línea nueva (igual que `createDetalleVenta` con `idventa+idtelas+precio`).
3. Suma la cantidad al `stock` de `inventario` (crea la fila si no existe).

Por esto la pantalla de Fabricación (`/fabricacion`) registra cada aplique+color al toque (sin carrito): la agrupación por día ya la resuelve el datasource, no la UI.

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
- `lib/features/ventas/infrastructure/datasources/ventas_datasource_impl.dart` — lógica incremental de ventas (tabla `ventas`, solo telas)
- `lib/features/ventas/infrastructure/datasources/detalleVentas_datasource_impl.dart` — upsert por idtelas+precio al crear detalles
- `lib/features/apliques/infrastructure/datasources/apliques_datasource_impl.dart` — apliques, inventario, colores y producciones (fabricación sube stock)
- `lib/features/apliques/infrastructure/datasources/ventas_apliques_datasource_impl.dart` — venta de apliques: insert en `ventas_apliques` + detalles + descuento de stock
- `lib/features/sucursales/presentation/bloc/sucursal_disponibilidad_cubit.dart` — vinculación telas↔sucursal e inventario de apliques por sucursal
- `lib/features/dashboard/infrastructure/datasources/dashboard_datasource_impl.dart` — llama a las RPC del dashboard (`top_productos`, `resumen_ventas`, `resumen_ventas_apliques`)

## Rutas registradas

| Path | Screen |
|---|---|
| `/` | SucursalesScreen (ventas de telas) |
| `/venta-apliques` | VentaApliquesSucursalesScreen (elegir sucursal) |
| `/venta-apliques/:idsucursal` | VentaApliquesScreen (form con stock por color) |
| `/fabricacion` | ProduccionScreen (registrar producción → sube stock; una fila por aplique+color+sucursal+día, se acumula si ya hay una de hoy) |
| `/fabricacion/historial` | ProduccionesHistorialScreen (listado de producciones recientes) |
| `/sucursales` | SucursalesScreen (gestión) |
| `/sucursal/:idsucursal` | SucursalScreen (form + botón a disponibilidad) |
| `/sucursal-disponibilidad/:idsucursal` | SucursalDisponibilidadScreen (qué telas se venden en la sucursal) |
| `/telas` | TelasScreen |
| `/tela/:idtela` | TelaScreen |
| `/tela-colores/:idtela` | TelaColoresScreen (colores vinculados de la tela) |
| `/apliques` | ApliquesScreen (gestión de apliques) |
| `/aplique/:idaplique` | ApliqueScreen (form: nombre, dimensiones cm, costo fabricación, activo) |
| `/aplique-colores/:idaplique` | ApliqueColoresScreen (colores vinculados del aplique) |
| `/colores` | ColoresScreen (gestión de colores) |
| `/color/:idcolor` | ColorScreen (form: nombre + hex con preview; baja lógica) |
| `/ventas/:idsucursal` | VentasScreen |
| `/det_ventas/:idventa` | DetVentas |
| `/det_venta/:idsucursal` | DetVenta (formulario de registro; telas filtradas por disponibilidad de la sucursal) |
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
- Usa las RPC `top_productos(desde, hasta)`, `resumen_ventas(desde, hasta)` (telas) y `resumen_ventas_apliques(desde, hasta)` (apliques, migración 10) porque el cliente de Supabase no permite `GROUP BY`/`SUM` directo. Son `LANGUAGE sql STABLE` y comparan `fecha` como texto ISO8601. El dashboard muestra las tarjetas de resumen de telas y de apliques por separado.

## Supabase

- Credenciales e init en `lib/config/supabase/supabase_config.dart`; `SupabaseConfig.client` es el cliente compartido por todos los datasources.
- Las tablas tienen RLS habilitado con **políticas abiertas** (app de un solo usuario, sin login). Si se agrega Supabase Auth, restringir las políticas en `supabase/schema.sql`. **Toda tabla nueva necesita su política `acceso_total_*`** — sin política, PostgREST devuelve `[]` silenciosamente (pasó con `colores`, `inventario`, `apliques`, etc.; se corrigió en `supabase/rls_faltantes.sql`).
- **Baja lógica en todo:** ningún proceso elimina filas físicamente; se setea `activo = false` (`telas`, `sucursales`, `colores`, `apliques`, `inventario`, `tela_colores`, `aplique_colores`, `tela_sucursales`). Los listados filtran `activo = true`.
- **Colores por producto:** `tela_colores` (telas) y `aplique_colores` (apliques, migración `supabase/aplique_colores.sql`). Los selectores de color de Fabricación y de la disponibilidad por sucursal solo ofrecen los colores vinculados al aplique.

## Comandos

```bash
flutter pub get          # instalar dependencias
flutter run              # correr en debug
flutter build apk        # build Android APK
flutter analyze          # lint check
flutter test             # 163 tests unitarios/de widget (fakes en test/helpers/)
flutter clean            # limpiar build
```

Los tests cubren mappers, cubits de formularios, blocs de listas y utilidades con **fakes en memoria** (`test/helpers/fake_repositories.dart`) — nunca tocan Supabase real. Los datasources `*_impl` y las pantallas con router no se testean (requieren `Supabase.initialize()`).

## Entorno local (pruebas sin tocar producción)

Supabase local en Docker vía CLI (`npx supabase@latest ...`, no hace falta instalarla global). `SupabaseConfig` lee `SUPABASE_URL`/`SUPABASE_KEY` de `--dart-define`; **sin defines apunta a producción**. Con base local la app muestra una cinta verde "LOCAL".

```bash
npx supabase@latest start -x realtime,storage-api,imgproxy,edge-runtime,logflare,vector,supavisor,mailpit
flutter run -d windows --dart-define-from-file=env/local.json
flutter run --dart-define-from-file=env/local-android.json   # emulador (10.0.2.2)
npx supabase@latest db reset   # vuelve a cero: migraciones + seed.sql
npx supabase@latest stop
```

- Studio local: `http://127.0.0.1:54323`. API: `http://127.0.0.1:54321`.
- `supabase/migrations/20260925000000_prod_schema.sql` es un **dump del esquema real de producción** (2026-09-25) — más fiel que `schema.sql`.
- `supabase/seed.sql` es una copia de los **datos reales**, está en `.gitignore` (no subir). Para refrescarla: `npx supabase@latest db dump --linked --data-only -f supabase/seed.sql` (sin `--use-copy`, el seed no acepta `COPY`).
- El `link` a producción necesita IPv4 vía pooler: si `db dump` da `DbConfigIpv6Error`, repetir `npx supabase@latest link --project-ref tacgylhmwqkfhdkpcvkr`.
- `mailpit` se excluye porque su puerto 54324 chocó en esta máquina.
- Android: `http://` habilitado solo en `android/app/src/debug/AndroidManifest.xml`.

## Notas Windows / Android

Si aparece `this and base files have different roots` en Gradle (común cuando el proyecto está en `F:`/`D:` y el pub cache en `C:`):

```bash
flutter clean
cd android && ./gradlew clean
flutter pub get
```
