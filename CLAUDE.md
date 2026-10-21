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
| **ventas_app_android** | Kotlin + Compose | Port nativo Android: telas y apliques (ventas de telas y de apliques, fabricación, colores, dashboard) → `github.com/ElianHuanca/ventas_app_android` (privado). Su build type `local` usa el mismo Supabase de Docker que este repo (ver "Entorno local") |
| **ventas_app_ios** | Swift + SwiftUI | Port nativo iOS, solo local (`F:\Elian\ventas_app_ios`). Usa las mismas tablas y RPC salvo `top_apliques` e `inventario_con_ventas` |

En disco son carpetas hermanas (`F:\Elian\ventas_app`, `F:\Elian\ventas_app_android`, `F:\Elian\sitio`); el vault de notas está en `F:\Elian\notas`.

**Este repo es el dueño del esquema.** `supabase/` es la fuente de verdad para las otras apps:

- **`supabase/migrations/`** — la fuente de verdad. `20260925000000_prod_schema.sql` es el dump de producción; cada cambio posterior es un archivo nuevo `<timestamp>_*.sql` (ver el runbook en el vault).
- **`supabase/landing.sql`** — las vistas públicas que consume la web (`sitio`). Es `CREATE OR REPLACE`, re-aplicable. Las vistas `catalogo_*_web` también están copiadas en `migrations/20261003000000_vistas_catalogo_web.sql`: si se cambian, actualizar ambos.
- ⚠️ **`supabase/schema.sql` está obsoleto** (no describe producción; re-aplicarlo rompe cosas). Solo referencia histórica. Lo mismo los `.sql` sueltos de `supabase/` (ya aplicados, no re-ejecutables).

Al cambiar el esquema: migración nueva → `npx supabase@latest db reset` en local → anotarla en el registro de migraciones del vault → aplicarla en el SQL Editor. **Antes de renombrar o borrar una columna o un parámetro de una RPC, correr `npx supabase@latest test db`**: `09_contrato.test.sql` fija lo que usan Flutter, Android, iOS y la web, y su mensaje dice qué app se rompe.

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
| `ventas_apliques` | id, fecha, total, ganancias, descuento, idsucursales — **solo apliques** (migración 10). **Una por sucursal+día** (como en el PHP `textiles`): cada registro se suma a la venta del día |
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
| `operaciones_aplicadas` | id (uuid, PK), rpc, resultado, creada — claves de idempotencia de las escrituras ya aplicadas (migración `20261020000000_idempotencia_y_venta_telas.sql`); la escriben solo las RPC, nadie la lee ni la borra |

`fecha` se almacena como **TEXT ISO8601** (igual que en la versión SQLite) para preservar la lógica de comparación — las RPC comparan lexicográficamente y eso depende de este formato. Los precios son `NUMERIC` (no `REAL`) para evitar errores de coma flotante en dinero.

Las tablas nuevas (`categorias`, `colores`, `tela_colores`, `tela_fotos`) y las columnas agregadas a `telas`/`sucursales` existen para el catálogo web; esta app gestiona `colores` (módulo `/colores`, baja lógica) pero **no escribe** `tela_colores`/`tela_fotos` (solo `tela_colores` en la gestión de colores por tela).

### Convención importante: `actualizarVenta`

`VentasDatasourceImpl.actualizarVenta` mantiene la convención **incremental**: suma el delta al valor actual (`total = total + delta`), excepto `fecha` que se asigna directa. Siempre pasar **deltas** (no valores absolutos). La suma la hace la DB en un solo `UPDATE` (RPC `incrementar_venta`) para que dos dispositivos no se pisen. **La app ya no la usa para vender ni para borrar líneas** (eso va por `registrar_venta_telas` / `borrar_detalle_venta`, abajo); `incrementar_venta` y `registrar_detalle_venta` siguen en la base porque las usan Android e iOS (`09_contrato`).

### Escrituras multi-tabla → RPC transaccionales

Todo lo que antes era "leer → sumar en Dart → escribir" en varias llamadas HTTP ahora es una RPC (migraciones `20261003000100_integridad_stock_y_ventas.sql` y `20261020000000_idempotencia_y_venta_telas.sql`). **No volver al patrón leer-y-escribir ni a encadenar llamadas desde el cliente**: con dos dispositivos pierde unidades, y una falla de red en el medio deja la venta a medias.

| Datasource | RPC | Qué hace en una transacción |
|---|---|---|
| `VentasApliquesDatasourceImpl.createVentaAplique` | `crear_venta_apliques` (+ `p_id_operacion`) | **venta del día** de la sucursal (la crea o le suma total/ganancias/descuento) + líneas acumuladas por `(aplique, color, precio)` + descuento de stock; **falla entera** si alguna línea no tiene stock (o no está en inventario activo) o su color no está vinculado al aplique (`aplique_colores` activo) |
| `ApliquesDatasourceImpl.createProduccion` | `registrar_produccion` (+ `p_id_operacion`) | cabecera del día + líneas acumuladas + suma al stock |
| `VentasDatasourceImpl.registrarVentaTelas` | `registrar_venta_telas` (+ `p_id_operacion`) | **venta del día** de telas (la crea o la reusa) + líneas acumuladas por `(idventa, idtelas, precio)` + a la venta el total y las ganancias **de esas líneas** (las calcula la RPC) y el descuento: el total de la venta es siempre la suma de sus líneas. La `fecha` de una venta del día que ya existe **no se toca** (queda la del primer registro, como en apliques; antes `incrementar_venta` la pisaba con la hora del último). Rechaza sin líneas, líneas sin total/ganancias y descuento negativo |
| `DetalleVentasDatasourceImpl.borrarDetalleVenta` | `borrar_detalle_venta` | borra la línea y le resta su total/ganancias a la venta; devuelve la venta (o null si la línea ya no estaba: no hace nada, es idempotente sin clave) |
| `DetalleVentasDatasourceImpl.createDetalleVenta` | `registrar_detalle_venta` | upsert por `(idventa, idtelas, precio)` sumando cantidad/total/ganancias, sin tocar la venta. Ya no lo usa la venta: queda para armar datos (integración, macro-benchmarks) |
| `VentasDatasourceImpl.actualizarVenta` | `incrementar_venta` | suma deltas a la venta (sin uso en la app; ver arriba) |

`VentasDatasourceImpl.createVenta` (solo para armar datos) choca con el UNIQUE `(idsucursales, día)` si otro dispositivo creó la venta del día entre medio: atrapa el `23505` y devuelve la existente.

**Idempotencia (`p_id_operacion`).** Las tres RPC de escritura con carrito reciben una clave `uuid` por envío (`DEFAULT NULL`, al final de la firma: las apps viejas, Android e iOS no la mandan y siguen andando igual que antes). La base la guarda en `operaciones_aplicadas` en la **misma transacción** (`INSERT ... ON CONFLICT DO NOTHING` al principio): con una clave ya aplicada la RPC devuelve el resultado de entonces **sin aplicar nada**; si la escritura falla, la clave se revierte con todo y el reintento se aplica; una clave usada por otra RPC es un error (HINT `operacion_de_otra_rpc`). En la app la genera `ClaveDeOperacion` (`lib/features/shared/clave_de_operacion.dart`, uuid v4 con `Random.secure`), una por cubit que guarda (`VentaApliquesFormCubit`, `ProduccionFormCubit`, `DetalleVentaFormCubit`): queda **atada a lo que se manda** (carrito/listado, descuento, día): el reintento del mismo envío lleva la misma; si cambió algo es otro envío y lleva otra; después de un envío que salió bien se descarta. Riesgo que queda: si después de una respuesta perdida el usuario **cambia** el carrito y guarda, es otro envío (si el primero había llegado, quedan los dos).

Restricciones en la DB (no solo en la UI): `inventario.stock >= 0`, cantidades `> 0`, precios/costos `>= 0`, y UNIQUE de una venta de telas y una de apliques por sucursal+día, una producción por sucursal+fecha, una línea por `(idventa, idtelas, precio)`, por `(idventa, idapliques, idcolor, precio)` y por `(idproduccion, idaplique, idcolor)`.

### Convención importante: fabricación (`producciones` / `detalle_produccion`)

`ApliquesDatasourceImpl.createProduccion` (RPC `registrar_produccion`) sigue el mismo patrón cabecera+detalle que ventas:

1. Usa la `producción` (cabecera) de esa sucursal con `fecha = hoy`; si no existe, la crea.
2. **Upsert** en `detalle_produccion` por `(idproduccion, idaplique, idcolor)`: si ya se fabricó ese aplique+color hoy, suma la cantidad a la línea existente; si no, inserta una línea nueva.
3. Suma la cantidad al `stock` de `inventario` (crea o reactiva la fila).

Por esto la pantalla de Fabricación (`/fabricacion`) registra cada aplique+color al toque (sin carrito): la agrupación por día ya la resuelve el datasource, no la UI.

## Vistas públicas (`supabase/landing.sql`)

Las consume la landing Next.js. Existen para no exponer datos sensibles:

- **`top_telas_web`** — top 6 telas por `SUM(detalle_ventas.total)` histórico. Publica `posicion`, **no el monto**, y nunca `precxcompra`. Agrupa por `idtelas` (no por `nombre`) para que renombrar una tela no parta su historial. Aplica `NULLIF(precio, 0)`: **precio 0 = no se vende en esa modalidad**.
- **`sucursales_web`** — sucursales con `activo = true`.

Ambas con `GRANT SELECT ... TO anon`. Si se cambia una columna que estas vistas leen, hay que volver a aplicar `landing.sql`.

## Archivos clave

- `lib/main.dart` — entry point, init de Supabase + BLoC providers
- `lib/config/supabase/supabase_config.dart` — credenciales e init del cliente
- `supabase/migrations/` — esquema PostgreSQL, RLS y RPC (fuente de verdad; `schema.sql` está obsoleto)
- `supabase/landing.sql` — vistas públicas de la landing
- `lib/config/router/app_router.dart` — todas las rutas (GoRouter + BLoC providers por ruta)
- `lib/config/theme/app_theme.dart` — tema Material 3
- `lib/features/ventas/infrastructure/datasources/ventas_datasource_impl.dart` — venta de telas en una llamada (`registrarVentaTelas`, RPC `registrar_venta_telas`) y la convención incremental de `actualizarVenta` (tabla `ventas`, solo telas)
- `lib/features/ventas/infrastructure/datasources/detalleVentas_datasource_impl.dart` — borrar una línea (`borrarDetalleVenta`, RPC `borrar_detalle_venta`) y el upsert por idtelas+precio para armar datos
- `lib/features/shared/clave_de_operacion.dart` — clave de idempotencia (`p_id_operacion`) de cada envío: uuid v4, la misma en los reintentos del mismo envío
- `lib/features/apliques/infrastructure/datasources/apliques_datasource_impl.dart` — apliques, inventario, colores y producciones (fabricación sube stock)
- `lib/features/apliques/infrastructure/datasources/ventas_apliques_datasource_impl.dart` — venta de apliques: insert en `ventas_apliques` + detalles + descuento de stock
- `lib/features/sucursales/presentation/bloc/sucursal_disponibilidad_cubit.dart` — vinculación telas↔sucursal (solo telas: el inventario de apliques no tiene pantalla de gestión; `addInventario`/`removeInventario` no los llama ninguna)
- `lib/features/apliques/domain/reposicion.dart` — regla de reposición (cuándo falta un aplique+color y cuánto hacer); la usa la pantalla Inventario
- `lib/features/dashboard/infrastructure/datasources/dashboard_datasource_impl.dart` — llama a las RPC del dashboard (`top_productos`, `top_apliques`, `resumen_ventas`, `resumen_ventas_apliques`)

## Rutas registradas

| Path | Screen |
|---|---|
| `/login` | LoginScreen (sin sesión todas las rutas redirigen acá) |
| `/` | SucursalesScreen (ventas de telas) |
| `/venta-apliques` | VentaApliquesSucursalesScreen (elegir sucursal) |
| `/venta-apliques/:idsucursal` | VentasApliquesScreen (ventas de la sucursal, una por día) |
| `/venta-apliques/registro/:idsucursal` | VentaApliquesScreen (form con stock por color) |
| `/venta-apliques/detalle/:idventa?fecha=` | VentaApliquesDetalleScreen (líneas de la venta del día) |
| `/fabricacion` | FabricacionSucursalesScreen (elegir sucursal) |
| `/fabricacion/:idsucursal` | ProduccionesScreen (producciones de la sucursal, una por día) |
| `/fabricacion/registro/:idsucursal` | ProduccionScreen (registrar producción → sube stock; una fila por aplique+color+sucursal+día, se acumula si ya hay una de ese día) |
| `/fabricacion/detalle/:idproduccion` | ProduccionDetalleScreen (líneas de la producción) |
| `/inventario` | InventarioSucursalesScreen (elegir sucursal) |
| `/inventario/:idsucursal` | InventarioScreen (faltantes de apliques y cuánto hacer; los manda al fabricante por WhatsApp o los copia) |
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
| `/dashboard/telas` | DashboardScreen de telas (submenú "Dashboard → Telas") |
| `/dashboard/apliques` | DashboardScreen de apliques (submenú "Dashboard → Apliques") |

## Convenciones de estado

- **BLoC** para estado de features (listas, CRUD)
- **Cubit** para estado de formularios
- Los BLoC providers se crean a nivel de ruta en `app_router.dart`
- `DetalleVentaFormCubit` acumula items en memoria antes del submit; si se añade el mismo producto al mismo precio **suma la cantidad** en vez de crear un item nuevo
- Al hacer submit va **una sola llamada** (`registrar_venta_telas`) con el carrito entero y su clave de operación; la RPC hace el **upsert** de cada línea (por `idventa + idtelas + precio`; si existe suma, si no inserta) y suma los totales a la venta del día
- Los cubits que guardan (`DetalleVentaFormCubit`, `VentaApliquesFormCubit`, `ProduccionFormCubit`) conservan el carrito/listado si el envío falla, para volver a tocar Guardar con la misma clave; `ProduccionFormCubit` lo vacía apenas el registro sale bien, aunque después falle el refresco del stock

## Dashboard

- En el menú lateral es una sección **Dashboard** con dos submenús, **Telas** (`/dashboard/telas`) y **Apliques** (`/dashboard/apliques`). `NavigationDrawer` solo numera los destinos que son hijos directos, así que el "submenú" es un título + dos destinos (índices 7 y 8 del `MenuIndexCubit`); sus `Text` llevan `semanticsLabel` "Dashboard telas/apliques" porque el lector de pantalla no lee el título al tocar
- Cada ruta crea su `DashboardCubit(linea: LineaDashboard.telas | .apliques)`; `DashboardScreen` toma la línea del cubit (título, "telas"/"apliques", mts/uds). Cada pantalla: período arriba, tarjetas de resumen (total, ganancias, descuentos) y el ranking completo por total vendido o por cantidad (metros en telas, unidades en apliques)
- Rango default: primer día del mes actual → hoy; el selector usa `showDateRangePicker`. El período no se comparte entre los dos submenús (cada uno tiene su cubit)
- Cada cubit carga solo las 2 RPC de su línea, juntas: `top_productos` + `resumen_ventas` (telas), `top_apliques` + `resumen_ventas_apliques` (apliques). Existen porque el cliente de Supabase no permite `GROUP BY`/`SUM` directo. Son `LANGUAGE sql STABLE` y comparan `fecha` como texto ISO8601
- `top_apliques` (migración `20261006000000_top_apliques.sql`) tiene las mismas columnas que `top_productos`; agrupa por `idapliques` con el nombre de la tabla `apliques` (no el `nombre` del detalle, que trae basura) y suma todos los colores

## Inventario (faltantes para el fabricante)

- Menú "Inventario" (después de Fabricación) → elegir sucursal → `/inventario/:idsucursal`. Lista cada aplique+color del inventario con su stock, lo que vende por semana y cuánto hacer; por defecto solo los faltantes ("Faltan | Todos"). **"Enviar por WhatsApp"** abre `https://wa.me/?text=…` (sin número: WhatsApp pregunta a quién) con `url_launcher`; **"Copiar lista"** deja el mismo texto en el portapapeles. El texto lo arma `mensajeFaltantes` (`domain/mensaje_faltantes.dart`).
- Datos: RPC **`inventario_con_ventas(p_sucursal_id, desde, hasta)`** (migración `20261015000000_inventario_con_ventas.sql`, solo lectura): filas de `inventario` activas con aplique, color y vínculo `aplique_colores` activos (lo mismo que ofrece la venta), con `vendidas` (esa sucursal, en el rango) y `vendidas_otras` (promedio de las otras sucursales que vendieron).
- **Regla** (`ReglaReposicion` en `domain/reposicion.dart`, pura y testeada; la RPC no decide nada): venta semanal = lo vendido en las últimas **4 semanas** / 4; **mínimo** = ⌈venta semanal × 2.5⌉ (el fabricante tarda 3–6 días hábiles —lun, mar, jue, vie—: 1.5 semanas en el peor caso, + 1 de colchón); **falta** si `stock ≤ mínimo` y se pide hasta el **doble del mínimo**. Lo que no se vendió en la ventana **no se pide**. Orden: faltantes primero, el que se termina antes arriba.
- **Sucursal sin ventas propias** en la ventana (p. ej. una tienda que recién empieza a vender apliques): se estima con `vendidas_otras` y la pantalla lo avisa ("se estiman N por semana").
- `InventarioCubit(hoy:)` recibe la fecha para que las capturas sean determinísticas.

## Login (Supabase Auth)

- Feature `lib/features/auth/`: `AuthRepository` (impl sobre `supabase.auth`), `LoginFormCubit`, `LoginScreen`.
- El router (`createAppRouter(authRepository:)`) redirige a `/login` si no hay sesión y vuelve a `/` al entrar (`redireccionPorSesion` + `SesionListenable` como `refreshListenable`). La sesión queda guardada en el dispositivo; "Cerrar sesión" está al pie del menú lateral.
- **No hay registro desde la app**: las cuentas se crean en el dashboard de Supabase (Authentication → Users) y el sign-up público está desactivado. Modelo actual: **logueado = acceso total** (sin roles).
- **La base exige login** desde el 2026-10-04 (`migrations/20261004000000_solo_usuarios_logueados.sql`): `anon` no lee ni escribe tablas ni RPC; solo las vistas `*_web` siguen públicas. Una versión vieja de la app (sin login) ya no funciona contra producción.
- Local: crear un usuario con `curl http://127.0.0.1:54321/auth/v1/admin/users` y la secret key local (`npx supabase status`), con `"email_confirm": true`.

## Supabase

- Credenciales e init en `lib/config/supabase/supabase_config.dart`; `SupabaseConfig.client` es el cliente compartido por todos los datasources.
- RLS habilitado en todas las tablas con políticas **`solo_logueados_*`** (`FOR ALL TO authenticated USING (true)`): cualquier usuario logueado tiene acceso total (sin roles). `anon` no tiene permisos sobre tablas, secuencias ni funciones; solo `SELECT` en las vistas `*_web` (la web).
- **Toda tabla nueva necesita su política `solo_logueados_*`** — sin política, PostgREST devuelve `[]` silenciosamente (pasó con `colores`, `inventario`, `apliques`, etc.). Y como el default ya no le da nada a `anon`, una RPC o vista pública nueva necesita su `GRANT` explícito.
- **Sin `DELETE` físico** salvo en `ventas` y `detalle_ventas` (las apps borran ventas/líneas), ni `TRUNCATE` en nada. Si una feature nueva necesita borrar físicamente, requiere migración con `GRANT DELETE ... TO authenticated`.
- **Baja lógica en todo:** ningún proceso elimina filas físicamente; se setea `activo = false` (`telas`, `sucursales`, `colores`, `apliques`, `inventario`, `tela_colores`, `aplique_colores`, `tela_sucursales`). Los listados filtran `activo = true`.
- **Colores por producto:** `tela_colores` (telas) y `aplique_colores` (apliques, migración `supabase/aplique_colores.sql`). Los selectores de color de Fabricación, de la **venta de apliques** y de la disponibilidad por sucursal solo ofrecen los colores vinculados al aplique: deshabilitar un color en `/aplique-colores/:idaplique` lo saca de la venta aunque tenga stock (`ApliquesDatasourceImpl.getStock` filtra el inventario por `aplique_colores` activos). La base también lo exige (migración `20261007000000_venta_apliques_colores_vinculados.sql`): `crear_venta_apliques` rechaza la venta entera con `Color no habilitado para el aplique` (HINT `color_no_vinculado`), así que ni una app vieja ni el port iOS pueden venderlo.

## Comandos

```bash
flutter pub get          # instalar dependencias
flutter run              # correr en debug
flutter build apk        # build Android APK
flutter analyze          # lints estrictos (ver "Lints"): tiene que quedar limpio
flutter test             # 931 unitarios/de widget + 168 capturas golden (sin omitidos)
flutter test --exclude-tags golden          # sin las capturas (p. ej. fuera de Windows)
flutter test test/goldens --update-goldens  # regenerar capturas tras un cambio visual buscado
flutter test benchmark/micro                # 176 micro-benchmarks (~1 min)
flutter test --exclude-tags golden --coverage && dart run tool/cobertura.dart --minimo 83   # cobertura (CI)
flutter test red --dart-define-from-file=env/local.json --concurrency=1   # fallas de red (Supabase local)
flutter clean            # limpiar build
```

## Tests

| Tipo | Dónde | Contra qué |
|---|---|---|
| Unitarios | `test/` (mappers, cubits, blocs, repositorios, router, utilidades) | **fakes en memoria** (`test/helpers/fake_repositories.dart`, `fake_datasources.dart`), nunca Supabase |
| De widget | `test/` (todas las pantallas y widgets compartidos; la navegación se verifica con un `GoRouter` de rutas stub) | los mismos fakes |
| Captura (golden) | `test/goldens/` (todas las pantallas y widgets compartidos, en cada estado) y `test/goldens/pantalla_chica/` (cada pantalla en 360×640 dp con letra grande) | los mismos fakes; compara contra PNG |
| Property-based | `test/propiedades/` (carritos, colores/hex, mappers, fechas, router, dashboard) | glados: 500 entradas generadas por propiedad, contra un modelo en enteros |
| Micro-benchmarks | `benchmark/micro/` (mappers, utilidades, router, cubits, blocs, montaje de widgets) | fakes; µs/op o ms/montaje con presupuesto |
| Macro-benchmarks | `benchmark/macro/` + `test_driver/perf_driver.dart` | la app completa en el **celular**, contra el Supabase local |
| De integración | `integration_test/app_test.dart` | la app completa (`HuantexApp`: router, login, datasources, RLS, RPC) contra el **Supabase local** |
| Fugas de memoria | todos los `testWidgets` de `test/` (`test/flutter_test_config.dart`) | leak_tracker: falla si un controller/notifier/FocusNode quedó sin `dispose()` |
| Accesibilidad | `test/accesibilidad/` (todas las pantallas, en sus estados principales) | fakes; guías de flutter_test: toque ≥ 48 dp (Android) / 44 (iOS), etiquetas para lector de pantalla, contraste WCAG |
| Concurrencia | `concurrencia/` | 8 clientes Supabase a la vez contra el **Supabase local**: las RPC no pierden unidades ni duplican cabeceras |
| Base de datos (pgTAP) | `supabase/tests/database/` | la **base local** en SQL: RLS y permisos, RPC, restricciones, dashboard, vistas web y el **contrato** con las otras apps |
| Red (fallas de conexión) | `red/` | la app (cubits y datasources reales vía `SupabaseConfig.client`) con la red de `RedConFallas` contra el **Supabase local**: respuesta perdida después del commit, sin conexión, falla en la llamada N o en una RPC |
| Firma, actualización y monkey | `tool/*.dart` | el APK (certificado oficial), y la app instalada en el **emulador**: actualizar encima de la versión de `main`, y miles de toques al azar |
| Mutación | `mutacion/*.xml` (carritos y formularios; mappers, utilidades y dashboard; router y listados) | mutation_test: altera `lib/` línea por línea y verifica que algún test de `test/` lo detecte |

Cada flujo (login, sucursales y su disponibilidad, telas, colores, apliques, fabricación, venta de apliques, venta de telas, dashboard, inventario, menú) tiene los seis tipos. Los tests de `test/` siguen la estructura de `lib/` (los de `features/shared/` van sueltos en `test/features/shared/`). Los fakes no se pisan entre tests: si uno necesita otro comportamiento, se hace una subclase local en ese archivo.

**Tests omitidos = bugs conocidos.** Los `skip: true` describen el comportamiento correcto y llevan un comentario `// bug: archivo:línea — qué pasa`. Al arreglar el bug, quitar el `skip` (el test tiene que pasar; si es una captura, generarla con `--update-goldens`).

### Capturas (golden)

- `test/goldens/<feature>/<pantalla>_golden_test.dart`, PNG en `goldens/<pantalla>_<estado>.png` al lado. Etiqueta `golden` (`dart_test.yaml`).
- `montarParaCaptura` / `compararCaptura` (`test/goldens/golden_helpers.dart`) montan la pantalla con el tema real, en español, a 412×915 dp. `test/goldens/flutter_test_config.dart` carga Roboto y MaterialIcons del SDK (si no, flutter_tester dibuja cuadrados) y Arial de Windows como respaldo de símbolos que Roboto no trae (la "→" del dashboard).
- **Generadas en Windows**: el antialiasing cambia entre SO; en otro, regenerarlas o `--exclude-tags golden`. Las sombras salen como contorno (flutter_test las apaga por determinismo).
- Determinísticas: nada de `DateTime.now()` (las fechas se fijan por el cubit, p. ej. `onFechaChanged`, `cambiarRango`). Un loader se captura con un fake que espera un `Completer`, `asentar: false` y `pump(400 ms)`; el `complete()` va en un `finally` (si la captura falla y queda pendiente, `Bloc.close()` cuelga el test 10 min).
- Un cambio visual buscado se acepta regenerando (`--update-goldens`) y revisando el PNG en el diff.
- **Pantalla chica** (`test/goldens/pantalla_chica/`): cada pantalla (las rutas de la tabla y el menú abierto) en un teléfono de gama baja (`telefonoChico`, 360×640 dp) con la letra del sistema en "Grande" (`letraGrande`, 1.3), con `montarChica` / `compararChica` → `goldens/<pantalla>_chica.png`. Ahí aparecen los textos que desbordan o se cortan. `montarParaCaptura(escalaTexto:)` fija la escala por `textScaleFactorTestValue`, de donde la lee el `MediaQuery` igual que en el celular.
- Un `DataTable` que no entra en el ancho **no tira overflow**: achica las columnas y recorta lo que sobra (la columna de borrar quedaba inalcanzable). Por eso las tablas van en `TablaDesplazable` (`lib/features/shared/widgets/tabla_desplazable.dart`): si entra se dibuja igual; si no, se desplaza de costado.

### Micro-benchmarks

- `flutter test benchmark/micro` (no corren con `flutter test` a secas). Helpers en `benchmark/micro/medicion.dart`: `microBenchmark` / `microBenchmarkAsync` (µs por operación, con benchmark_harness) y `widgetBenchmark` (ms por montaje desde cero). Resultados en `build/benchmarks/micro/<grupo>.json`; `--dart-define=BENCH_MS=3000` mide más tiempo.
- Corren en JIT con asserts: sirven para comparar corridas y frenar regresiones groseras, no son números de release. Cada uno tiene un presupuesto ~10x el peor valor medido y falla si lo excede.
- `benchmark/micro/widgets/` reusa el `flutter_test_config.dart` de las capturas (con Ahem el texto es más ancho y el dashboard desborda).
- Con la máquina cargada (otros `flutter test`, Gradle, emulador) la VM de Dart puede quedarse sin memoria: correrlos solos.

### Macro-benchmarks

La app completa en el celular, por flujo: latencia end-to-end (toque → dato visible) y fluidez (`FrameTiming`: build/raster promedio, p90, p99, frames perdidos, más el timeline). Qué mide cada clave: cabecera de `benchmark/macro/app_benchmark.dart`.

```bash
npx supabase@latest start -x realtime,storage-api,imgproxy,edge-runtime,logflare,vector,supavisor,mailpit
adb reverse tcp:54321 tcp:54321
flutter drive --driver=test_driver/perf_driver.dart --target=benchmark/macro/app_benchmark.dart --profile --no-dds -d <id del celular> --dart-define-from-file=env/local-usb.json
```

- **Números de referencia solo en `--profile` y en el celular físico** (los emuladores no soportan profile; en debug salen varias veces más lentos). `android/app/src/profile/AndroidManifest.xml` permite http para llegar al Supabase local (release no).
- Resultados en `build/benchmarks/macro/`: `resultados.json` y un `<clave>.timeline.json` / `.timeline_summary.json` por traza (se abren en Perfetto).
- Crea datos con prefijo `BM ` (150 telas, 150 apliques, 40 colores para que haya scroll real); se limpian con `db reset`.
- El target no tiene sufijo `_test` a propósito: así no lo toman `flutter test integration_test` ni `flutter test benchmark/micro`.

### Integración

```bash
npx supabase@latest start -x realtime,storage-api,imgproxy,edge-runtime,logflare,vector,supavisor,mailpit
# Celular por USB (pantalla desbloqueada y encendida durante toda la corrida):
adb reverse tcp:54321 tcp:54321
flutter test integration_test -d <id del celular> --dart-define-from-file=env/local-usb.json
# o emulador (10.0.2.2 llega a la PC sin adb reverse). Sin ventana aguanta mejor,
# pero su pantalla se duerme y la app deja de dibujar: mantenerla despierta
emulator -avd Medium_Phone_API_36.1 -no-window -no-audio -no-boot-anim -no-snapshot-save
adb -s emulator-5554 shell svc power stayon true && adb -s emulator-5554 shell wm dismiss-keyguard
flutter test integration_test -d emulator-5554 --dart-define-from-file=env/local-android.json
```

Un test que se queda quieto sin fallar (sin timeout de `esperarHasta`) casi siempre es la pantalla del dispositivo apagada (`adb shell dumpsys power | grep mWakefulness` dice `Asleep`) o la app de prueba en segundo plano: si otra app pasa al frente (o se toca Inicio), Android la congela. `adb shell dumpsys activity activities | grep topResumedActivity` lo muestra; se trae de vuelta (y el test sigue) con `adb shell monkey -p com.example.textiles_app -c android.intent.category.LAUNCHER 1`.

Otros cuelgues vistos (2026-10-15), los dos en `(setUpAll)`:

- **El túnel `adb reverse` no responde** (pasó después de reiniciar Docker Desktop; `adb kill-server` no alcanzó): se prueba con `adb shell "printf 'GET /auth/v1/health HTTP/1.0\r\n\r\n' | nc -w 5 127.0.0.1 54321"` (tiene que devolver `HTTP/1.1 200`). Desenchufar y volver a enchufar el USB lo arregla un rato, pero con este celular se volvió a cortar a los pocos minutos. Lo estable fue **todo por Wi-Fi**: `adb -s <id usb> tcpip 5555`, `adb connect <IP del celular>:5555` y correr con `-d <IP del celular>:5555` y un `--dart-define-from-file` cuya `SUPABASE_URL` sea `http://<IP de la PC>:54321` (cualquier URL que no sea la de producción cuenta como local; sin `adb reverse`). Así pasaron los 29.
- **La app de prueba no llega a inicializar Supabase** (el log no dice `Supabase init completed` y `docker logs supabase_auth_ventas_app` no muestra pedidos): quedó estado de una corrida anterior; `adb shell pm clear --user 0 com.example.textiles_app` y volver a correr.
- `--name` con acentos no encuentra ningún test en Windows (se rompe la codificación del argumento) y la corrida espera para siempre: filtrar por un pedazo sin acentos (`--name "borrar una l"`).

- **Solo corren contra la base local**: `prepararBaseLocal()` corta antes de conectarse si `SupabaseConfig.isLocal` es `false` (sin `--dart-define` apuntaría a producción).
- Se crean su usuario (`integracion@example.com`) la primera vez, vía sign-up, que solo está habilitado en el `config.toml` local. Sobrevive hasta el próximo `db reset`.
- Estructura: `app_test.dart` es el **único punto de entrada** (la app se compila e instala una vez) y llama a los flujos de `flujos/*.dart` (sin sufijo `_test` a propósito: si no, `flutter test` los correría como entradas sueltas). `datos.dart` crea los datos de cada test con los datasources reales.
- Cubren (29 tests): login; sucursales (alta, renombrar, baja lógica, disponibilidad de telas → venta, quitar una tela la saca de la venta y sin ninguna activa vuelve todo el catálogo); telas (alta, precio/desactivar → no se ofrece, colores); colores (alta con hex normalizado, renombrar, baja, hex inválido); apliques (alta/edición/desactivar, deshabilitar un color lo saca de Fabricación y de la venta, habilitarlo lo ofrece en Fabricación); fabricación (sube stock, acumula en el día, historial y detalle, fecha anterior, línea quitada no se registra); venta de apliques (descuenta stock, bloquea sobre-stock, acumula en la venta del día, detalle, línea quitada no descuenta stock, descuento); venta de telas (venta, acumula en el día, borrar línea descuenta el total, línea quitada del carrito, descuento, fecha anterior); dashboard (submenús Telas y Apliques, cambio de período); inventario (faltante con lo que hay que hacer y "Copiar lista" al portapapeles, lo que no se vende no falta). Cada uno verifica también las filas en la base.
- Dejan filas con prefijo `IT ` en casi todas las tablas: la base no permite borrar físicamente. Se limpian con `npx supabase@latest db reset`.
- La app de prueba se instala con el mismo `applicationId` que la oficial y la reemplaza en el celular. En Windows desktop (`-d windows`) no compila sin el toolchain C++ de Visual Studio.
- Helpers en `integration_test/helpers.dart`. Al menú se va con `irDesdeMenu` y al dashboard con `irAlDashboard(tester, 'Telas' | 'Apliques')`: "Telas" y "Apliques" están dos veces en el menú (gestión y submenú del dashboard). Las respuestas de Supabase no son frames, así que se espera con `esperarHasta` / `esperarQue` (no basta `pumpAndSettle`), se escribe con `escribir` (re-enfoca el campo; si no, el segundo `enterText` se pierde) y se eligen opciones de `DropdownMenu` con `elegir`. Fechas con `elegirFecha` / `elegirRango` (modo texto del selector, en el idioma del dispositivo). Para tocar un ítem de una lista recién recargada (al volver de un formulario), `tocarHasta`: el toque que cae mientras está el loader se pierde.
- `DropdownMenu` arma un `Text` oculto por cada opción: para verificar que algo ya no está en pantalla, buscarlo dentro de su contenedor (p. ej. el `DataTable`), no en toda la pantalla.

### Fugas de memoria

- `test/flutter_test_config.dart` activa `LeakTesting.enable()` (`leak_tracker_flutter_testing`): cada `testWidgets` de `test/` registra los objetos de Flutter que avisan su creación y su `dispose()` (`TextEditingController`, `FocusNode`, `ScrollController`, `AnimationController`, `ChangeNotifier`…). Si al final del archivo alguno sigue vivo, el test falla con la clase y el test donde se creó; `--dart-define=FUGAS_CON_PILA=true` agrega la pila de creación.
- Una fuga de `lib/` se arregla en `lib/` (falta un `dispose()`, un controller creado en `build`, un listener sin quitar); una del propio test, con `addTearDown(x.dispose)`. Solo lo del framework sin arreglo va en `withIgnored`, con su porqué.
- Flutter usa **solo** el `flutter_test_config.dart` más cercano: `test/goldens/` (y `benchmark/micro/widgets/`) tienen el suyo y no rastrean fugas; `test/accesibilidad/` encadena los dos.
- Los Bloc/Cubit no los ve: los creados a mano en un test se cierran con `addTearDown(bloc.close)`.

### Accesibilidad

- `test/accesibilidad/<feature>_accesibilidad_test.dart`. `verificarGuias(estado, montar)` (`accesibilidad_helpers.dart`) arma un test por guía de flutter_test: `androidTapTargetGuideline` (48×48), `iOSTapTargetGuideline` (44×44), `labeledTapTargetGuideline` y `textContrastGuideline`.
- Tamaños y etiquetas se miden con Roboto a 412×915 dp (como las capturas). El contraste, con la fuente de prueba (glifos sólidos) en una pantalla ancha: el antialiasing de Roboto hace que un texto negro mida gris.
- Un ícono tocable sin texto necesita `tooltip` (o `semanticLabel`); un `GestureDetector` encima de algo que ya tiene etiqueta, `excludeFromSemantics: true`. Una guía que una pantalla todavía no cumple va en `omitidas:` con su comentario `// bug:`.

### Property-based

- `test/propiedades/<tema>_propiedades_test.dart`, con glados. `propiedad(descripcion, generador, cuerpo)` (`generadores.dart`) verifica cada propiedad con 500 entradas generadas desde una semilla fija, así que la corrida es determinística. `--dart-define=PROPIEDADES_SEMILLA=n` explora otras entradas y `--dart-define=PROPIEDADES_FACTOR=10` corre 10 veces más casos. Corren con `flutter test` (están en `test/`).
- Si una falla, glados achica la entrada hasta la mínima que la rompe (`Failing for input: ...`). Al arreglar el bug, ese caso mínimo se agrega también como test puntual en el test del archivo arreglado.
- Los carritos (telas, apliques, fabricación) se comparan contra un modelo en enteros (centésimos): una línea por clave con la cantidad sumada, total y ganancias = suma de las líneas con 2 decimales y la mitad del centavo hacia arriba (como `numeric`), quitar todo vuelve a 0, el orden de agregado no cambia nada y nunca se pasa del stock.
- glados re-exporta `package:test` y choca con `flutter_test`: importarlo con `show`. Para enteros usar `any.entero(min, max)` de `generadores.dart` (el `intInRange` de glados achica de a 1 y una falla tardaba más de 10 minutos en llegar a la mínima).

### Mutación

```bash
dart pub global activate mutation_test   # una vez (1.8.0)
dart pub global run mutation_test mutacion/carritos_y_formularios.xml -o build/mutacion -f all
dart pub global run mutation_test --no-builtin mutacion/mappers_utilidades_dashboard.xml -o build/mutacion -f all
dart pub global run mutation_test mutacion/router_y_listados.xml -o build/mutacion -f all
```

- La herramienta muta un archivo de `lib/` por vez (operadores, `if`, defaults de `??`, booleanos, llamadas borradas, columnas mal leídas…), corre los tests y lo restaura. Un mutante que **sobrevive** (los tests siguen en verde) es un comportamiento que ningún test fija. Reporte en `build/mutacion/` (`-d` solo cuenta los mutantes).
- Cada mutante corre **solo los tests del archivo mutado**: los comandos del XML empiezan con `git diff --quiet -- <archivo> ||` (o, en mappers, el script `mutacion/mappers_utilidades_dashboard.dart` mira `git diff lib`). Por eso se corre con `lib/` **sin cambios sin commitear**, en Windows (pasan por cmd). Si se corta a la mitad, `git status` y `git checkout lib`.
- Lento: ~10–25 s por mutante (lo que tarda en arrancar `flutter test`), de 40 min a 2 h por XML. Correrlos de a uno y con la PC libre: con otros `flutter` corriendo un mutante puede cortarse por timeout.
- Un sobreviviente se mata con un test en el archivo de test de ese código; si es **equivalente** (mismo comportamiento, p. ej. un default que nada usa) se excluye en el XML con un comentario del porqué. Las tres configuraciones quedaron en 100 % (2026-10-12). Al cambiar uno de esos archivos, volver a correr su XML (o acotarlo a ese `<file>`).
- No corren con `flutter test`.

### Concurrencia

```bash
npx supabase@latest start -x realtime,storage-api,imgproxy,edge-runtime,logflare,vector,supavisor,mailpit
flutter test concurrencia --dart-define-from-file=env/local.json --concurrency=1
```

- 8 "dispositivos" (`SupabaseClient` independientes, cada uno con su sesión del usuario de integración) disparan la misma operación a la vez y se verifica qué quedó en la base: venta de telas (con el flujo de Android/iOS: la venta del día la crea uno y los demás recuperan esa por el `23505`, `registrar_detalle_venta` y `incrementar_venta` suman exacto; con el del Flutter: `registrar_venta_telas` desde 8 a la vez deja una venta y una línea con todo sumado y el total igual a la línea, y **la misma clave** desde 8 a la vez —reintentos que se cruzan— se aplica una sola vez), venta de apliques (última unidad: solo venden los que tienen stock y queda en 0; la venta del día es una sola) y fabricación (una cabecera, una línea, stock exacto; fabricar y vender a la vez).
- Cada escenario se repite `CC_REPETICIONES` veces (5 por defecto; `--dart-define=CC_REPETICIONES=20` para más cruces) con una sucursal nueva y fecha 2001-01-01, fuera de los rangos del dashboard y de la integración. Dejan filas con prefijo `CC `: se limpian con `db reset`.
- Son `test()` simples, sin `TestWidgetsFlutterBinding` (reemplaza el `HttpClient` y toda request devuelve 400). Las sesiones se guardan en `build/concurrencia/sesiones.json`: el auth local acepta 30 logins cada 5 minutos.

### Red (respuestas perdidas y reintentos)

```bash
npx supabase@latest start -x realtime,storage-api,imgproxy,edge-runtime,logflare,vector,supavisor,mailpit
flutter test red --dart-define-from-file=env/local.json --concurrency=1
# si vuelve a haber omitidos (bugs conocidos), correrlos igual: --dart-define=RED_CORRER_BUGS=true
```

- `RedConFallas` (`red/red_con_fallas.dart`) es un `http.Client`: **respuesta perdida** (manda el pedido, espera la respuesta entera —la base ya hizo commit— y lanza `ClientException: Connection closed while receiving data`) y **sin conexión** (falla antes de mandar); a qué pedidos alcanza: `Cuando.rpc`, `Cuando.tabla`, `Cuando.llamada(n)`, `Cuando.desdeLlamada(n)`, con `veces`. `red.registro` dice qué llegó a la base.
- `Celular.abrir()` (`red/celular.dart`) inicializa `Supabase.instance` con ese `httpClient` (misma URL y clave que `SupabaseConfig.init()`): los cubits y datasources reales se crean después y salen por esa red sin tocar `lib/`. `celular.base` es un cliente sano para preparar y verificar la base. Reusa las sesiones de `concurrencia/` (`abrirDispositivos(2)`).
- `test()` simples con `WidgetsFlutterBinding.ensureInitialized()` (lo pide `Supabase.initialize`), nunca `TestWidgetsFlutterBinding` (toda request devolvería 400).
- Datos con prefijo `RD ` (`DatosRD`) y fecha 2001-01-02; se limpian con `db reset`. `crear_venta_apliques` recibe `DateTime.now()` del datasource: la red lo cambia por la fecha fija (`fijarParametro`); el resto del cuerpo es el que arma la app.
- postgrest reintenta solo GET/HEAD (3 veces: 1 + 2 + 4 s) ante un error de red; los POST (todas las RPC) nunca. Un "sin conexión" en un GET tarda ~7 s en fallar.
- 27 tests, **sin omitidos** (2026-10-20). Los 9 bugs que había (las RPC de escritura no eran idempotentes: con la respuesta perdida y un segundo Guardar se aplicaban dos veces; la venta y el borrado de líneas de telas eran varias llamadas y una falla en el medio dejaba el total distinto de la suma de las líneas; Fabricación daba por fallido el registro si fallaba el refresco del stock y el reintento lo duplicaba) se arreglaron con la clave `p_id_operacion` y las RPC `registrar_venta_telas` / `borrar_detalle_venta` (ver "Escrituras multi-tabla"). Cubren, por flujo: respuesta perdida (sin reintentar, con un reintento y con dos perdidas seguidas: se aplica una vez), sin conexión (no llega nada y el reintento aplica una vez), venta de telas y borrado en **una sola llamada**, otra venta después de un reintento exitoso (la clave se renueva), el borrado que saca la línea de la pantalla recién cuando la base respondió, el refresco de stock fallido en Fabricación, y la **app vieja** (`crear_venta_apliques` sin `p_id_operacion`: sigue vendiendo, y sin clave su reintento vende de nuevo, como siempre).

### Base de datos (pgTAP)

```bash
npx supabase@latest test db   # con el Supabase local levantado
```

- `supabase/tests/database/NN_*.test.sql`: RLS y permisos de `anon`/`authenticated` en cada tabla (17, con `operaciones_aplicadas`), vista y RPC (01, 11 RPC); `crear_venta_apliques` (02); `registrar_produccion` (03); venta de telas: `registrar_detalle_venta` / `incrementar_venta` (las de Android e iOS) y `registrar_venta_telas` / `borrar_detalle_venta` (las del Flutter) (04); restricciones y UNIQUE (05); RPC del dashboard (06); vistas `*_web` (07); `inventario_con_ventas` (08); **contrato con las otras apps (09)**; **idempotencia** de las tres RPC con `p_id_operacion` (10: misma clave dos veces = una sola aplicación y el mismo resultado, aunque cambie el contenido; claves distintas = dos; sin clave = como antes; una falla no gasta la clave; una clave de otra RPC es error). 755 aserciones en total (2026-10-20).
- **Contrato (`09_contrato.test.sql`, 292 aserciones)**: lo que Flutter, Android (master), iOS y la web leen y escriben. Fija tablas y vistas; por columna, que exista, su tipo base (sin precisión) y NOT NULL donde una app la decodifica no nula (Android: tipo Kotlin no nulo, supabase-kt no usa `coerceInputValues`; Flutter: `as int`); las FK de los embeds (una sola por par de tablas, si no PostgREST da `PGRST201`), las PK de los upserts, que los inserts de las apps no dejen afuera una NOT NULL sin default, y las RPC con los nombres de sus parámetros (PostgREST llama por nombre), su resultado y las claves del JSON. Las apps mandan todos los parámetros por nombre **salvo `p_id_operacion`** (solo el Flutter nuevo): que sea opcional (`DEFAULT NULL`, al final) es parte del contrato, y `crear_venta_apliques` / `registrar_produccion` se llaman sin ella como Android e iOS. Reemplaza el "revisar a mano si otra app usa la columna". **Al cambiar lo que lee una app, actualizar sus listas** (`_columnas`, `_embeds`, `_inserts`, `_rpcs`) y el `plan(n)`. Sin `todo` desde que `top_productos` usa `COALESCE` (una tela con líneas sin total salía con `total_vendido` NULL y Android no la decodificaba).
- Cada archivo corre en una transacción con `rollback`: no deja datos. Al agregar una tabla, RPC o vista, sumarla acá (y actualizar el `plan(n)`).
- **Bugs conocidos = `todo()`**, el equivalente SQL del `skip` con su `bug: archivo:línea — qué pasa`. Al arreglarlo con una migración, sacar el `todo` (el test tiene que pasar).

### Lints

`analysis_options.yaml`: flutter_lints + `strict-casts` / `strict-inference` / `strict-raw-types` + 25 reglas curadas que detectan bugs (futures sin esperar, llamadas dinámicas, throws de algo que no es Exception, strings pegados…), cada una con su porqué; las de estilo puro quedaron afuera con su motivo. `flutter analyze` tiene que quedar limpio (también falla con "info"). Una fila de Supabase es `Map<String, dynamic>`: castear explícito (`json['nombre'] as String? ?? ''`); `rpc<T>` siempre con tipo (`rpc<List<dynamic>>`, `rpc<Map<String, dynamic>?>`, `rpc<dynamic>` si no se usa). Un Future que no se espera a propósito (`router.push` en tests, la carga del constructor de un cubit) va en `unawaited(...)`.

### Firma, actualización y monkey (`tool/`)

- `dart run tool/verificar_firma_apk.dart [apk]` (default `build/app/outputs/flutter-apk/app-release.apk`): compara el SHA-256 del certificado con el oficial (`48e1da98d963f1dddfb0965090b1599a4151cfabc6c5d2999b345d9fc4c47bfb`). Sale 1 si quedó con la clave de debug: `flutter build apk` NO muestra el aviso de `key.properties` faltante (en un worktree nuevo no está: es ignorado por git).
- Los builds **profile** salen siempre con la clave de debug de la PC (Flutter crea profile con `initWith(debug)` antes de que `build.gradle.kts` asigne la firma): no se instalan encima de la app oficial.
- `dart run tool/prueba_actualizacion.dart` (solo emulador, Supabase local levantado): compila `origin/main` en un worktree temporal y HEAD (profile + `env/local-android.json`), instala la vieja, inicia sesión, `adb install -r` la nueva y verifica misma firma, que actualiza en el lugar, que abre sin caerse y que la sesión sobrevive. Con poca RAM: `--solo-compilar` con el emulador apagado y después `--sin-compilar`. Logs en `build/actualizacion/`.
- `dart run tool/monkey.dart [--semillas 1,2,3] [--eventos 2000]` (solo emulador): instala `build/actualizacion/nueva.apk` (o compila con `--compilar`), entra con el usuario de integración y corre `adb shell monkey` por semilla; falla con CRASH, ANR o FATAL EXCEPTION. Logs en `build/monkey/`. ⚠️ Escribe datos al azar en el Supabase local (limpiar con `db reset`); no correrlo junto con la integración. El 2026-10-20: semillas 1, 2 y 3 × 2000 eventos sin fallas.
- Los scripts rechazan cualquier serial que no sea `emulator-*` (mismo applicationId que la app oficial: nunca en el celular). Con 16 GB y otras cargas el emulador se congela (qemu a 0 % de CPU, `adb shell` no responde) o se cae (`Could not allocated host memory`): matarlo y relanzarlo con `-memory 2048`; Gradle y el emulador no entran juntos.

## CI (GitHub Actions)

El repo es **público** desde el 2026-10-20 (minutos ilimitados en los runners de GitHub). Todo corre en runners de GitHub: **nunca un runner self-hosted** (en un repo público, un PR de un extraño ejecutaría código en esa máquina). Flutter fijo en **3.38.9** en `.github/actions/flutter` (si se sube, regenerar las capturas en Windows). Los jobs con base usan `.github/actions/supabase-local`: CLI 2.121.0, `supabase start -x realtime,storage-api,imgproxy,edge-runtime,logflare,vector,supavisor,mailpit,studio` con las migraciones y **sin seed**, y reescribe `env/local.json` / `env/local-android.json` con la URL y la clave de esa base (avisa si no coinciden con las del repo).

| Workflow | Cuándo | Jobs |
|---|---|---|
| `ci.yml` | cada PR y push a `main` (un push nuevo a un PR cancela la corrida anterior) | `analisis-y-tests` (ubuntu: `flutter analyze` + `flutter test --exclude-tags golden --coverage` + `tool/cobertura.dart --minimo 83`, sube `lcov.info`); `capturas` (windows-latest: `flutter test --tags golden`, sube `test/goldens/**/failures/` si falla); `base-de-datos` (pgTAP, incluido el contrato); `build-android` (`flutter build apk --debug`, Java 17) |
| `noche.yml` | 06:00 UTC diario + a mano | `concurrencia` y `red` contra el Supabase local; `integracion` en emulador Android API 34 (google_apis x86_64, KVM) que llega al Supabase del host por `10.0.2.2`; `micro-benchmarks` (informativo: los presupuestos se calibraron en la PC; sube los JSON) |
| `semanal.yml` | domingo 07:00 UTC + a mano | `mutacion`: matriz en windows-latest con cada XML de `mutacion/` (los comandos pasan por cmd), `mutation_test 1.8.0`, sube `build/mutacion/<xml>`; un XML que no existe se saltea con aviso |

- **Cobertura:** `tool/cobertura.dart` lee `coverage/lcov.info`, descarta archivos generados, imprime el % por carpeta (`--profundidad`, 3 por defecto) y el total, y falla si el total < `--minimo`. Medido el 2026-10-20: 83.6 % (lo más flojo: `lib/config/router`, 27.0 %; los `*DatasourceImpl` quedan en 0 % a propósito: hablan con Supabase y los cubren `red/` e integración). El mínimo va un punto abajo: si baja, falta un test para lo nuevo. Lista aparte los archivos de `lib/` con código que ningún test importa.
- `noche.yml` y `semanal.yml` se lanzan a mano desde Actions → Run workflow. Los artifacts (lcov, diferencias de capturas, benchmarks, reportes de mutación) quedan en cada corrida.
- Los workflows se validan con `actionlint` (binario de su release de GitHub; con `-shellcheck` si está shellcheck).

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

## Firma del APK

Release **y** debug se firman con una clave propia (desde 2026-10-04): `F:\Elian\claves\huantex-release.jks` (alias `huantex`, cert `CN=Huantex`, SHA-256 `48e1da98…7bfb`). Las contraseñas están en `android/key.properties` (ignorado por git, igual que `*.jks`). `android/app/build.gradle.kts` las lee; si falta `key.properties` firma con la clave de debug de la PC y avisa — ese APK **no** se puede instalar encima de la app oficial.

- ⚠️ **Si se pierde el `.jks` o su contraseña, ningún celular podrá actualizar** sin desinstalar. Respaldar ambos fuera de esta PC.
- Para compilar en otra PC: copiar el `.jks` y `key.properties` (ajustando `storeFile`).
- Verificar un APK: `apksigner verify --print-certs app-release.apk` (en `<sdk>/build-tools/<versión>/`).
- Error `INSTALL_FAILED_UPDATE_INCOMPATIBLE` / `signatures do not match` = el celular tiene una app firmada con otra clave → desinstalar una vez (`adb uninstall com.example.textiles_app`; los datos viven en Supabase).

## Notas Windows / Android

- **El release necesita `android.permission.INTERNET` en `android/app/src/main/AndroidManifest.xml`**: los manifests de debug y profile lo agregan solos, así que un build de debug funciona y el de release no se conecta a nada (el login dice "No se pudo iniciar sesión"). Faltó hasta el 2026-10-21; lo fija `test/android_manifest_test.dart`. Para revisar un APK: `aapt dump permissions <apk>` (en `<sdk>/build-tools/<versión>/`).

Si aparece `this and base files have different roots` en Gradle (común cuando el proyecto está en `F:`/`D:` y el pub cache en `C:`):

```bash
flutter clean
cd android && ./gradlew clean
flutter pub get
```
