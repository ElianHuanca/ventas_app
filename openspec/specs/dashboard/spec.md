---
description: Dashboards de ventas de telas y de apliques, cada uno con su período (por defecto el mes en curso), su resumen (total, ganancias, descuentos) y su ranking completo por total o por cantidad, con los avisos de período vacío y de carga fallida, y las consultas de solo lectura que lo alimentan (top_productos, top_apliques, resumen_ventas, resumen_ventas_apliques).
---

# Spec: dashboard

> Extraído automáticamente por spec-miner. Última extracción: 2026-11-06.
> Fuente: lib/features/dashboard/ (resumen_ventas.dart, top_producto.dart, dashboard_datasource.dart, dashboard_datasource_impl.dart, dashboard_repository_impl.dart, dashboard_cubit.dart, dashboard_screen.dart), lib/features/shared/widgets/side_menu.dart, lib/config/router/app_router.dart, supabase/migrations/20260925000000_prod_schema.sql (resumen_ventas, resumen_ventas_apliques), supabase/migrations/20261003000100_integridad_stock_y_ventas.sql, supabase/migrations/20261006000000_top_apliques.sql, supabase/migrations/20261020000000_idempotencia_y_venta_telas.sql (top_productos), supabase/migrations/20261004000000_solo_usuarios_logueados.sql
> Last verified: 2026-11-06 (commit 1d15233)

---

### Requirement: Abrir el dashboard de telas o de apliques desde el menú
<!-- id: SideMenu.build -->
<!-- entities: LineaDashboard -->
<!-- enforced: SideMenu.build(), createAppRouter(), DashboardScreen.build() -->

El menú lateral DEBE tener, después de las secciones de gestión, una sección titulada "Dashboard" con dos destinos: "Telas" y "Apliques" (para el lector de pantalla, "Dashboard telas" y "Dashboard apliques"). Cada uno DEBE abrir el dashboard de esa línea de negocio, con título "Dashboard telas" o "Dashboard apliques" y menú lateral; no hay pestañas para pasar de una línea a la otra.

#### Scenario: Submenú
<!-- test: test/features/shared/side_menu_test.dart::el dashboard es un submenú: Telas y Apliques bajo el título "Dashboard" -->
- **WHEN** el usuario abre el menú lateral
- **THEN** ve el título "Dashboard" con los destinos "Telas" y "Apliques" debajo

#### Scenario: Dashboard de telas
<!-- test: test/features/shared/side_menu_test.dart::tocar "Telas" navega a /dashboard/telas, guarda el índice 8 y cierra el menú -->
<!-- test: test/features/dashboard/dashboard_test.dart::el submenú Telas muestra solo las telas, sin pestañas -->
<!-- test: integration_test/flujos/dashboard.dart::el submenú Telas muestra las telas vendidas, en metros -->
- **WHEN** el usuario toca "Telas" bajo "Dashboard"
- **THEN** se cierra el menú y se abre "Dashboard telas" con solo datos de telas

#### Scenario: Dashboard de apliques
<!-- test: test/features/shared/side_menu_test.dart::tocar "Apliques" navega a /dashboard/apliques, guarda el índice 9 y cierra el menú -->
<!-- test: test/features/dashboard/dashboard_test.dart::el submenú Apliques muestra solo los apliques -->
<!-- test: integration_test/flujos/dashboard.dart::el submenú Apliques muestra los apliques vendidos -->
- **WHEN** el usuario toca "Apliques" bajo "Dashboard"
- **THEN** se cierra el menú y se abre "Dashboard apliques" con solo datos de apliques

---

### Requirement: Arrancar con el mes en curso como período
<!-- id: DashboardCubit.new -->
<!-- entities: DashboardState, LineaDashboard -->
<!-- enforced: DashboardCubit.new(), _RangoFechas.build() -->

Al abrirse, cada dashboard DEBE tomar como período desde el primer día del mes actual hasta hoy, mostrarlo bajo "Período" como "dd/MM/aaaa  →  dd/MM/aaaa", empezar en la vista "Por monto" y cargar los datos de inmediato. El período de cada dashboard es propio: NO DEBE compartirse entre Telas y Apliques ni conservarse al salir de la pantalla.

#### Scenario: Apertura
<!-- test: test/features/dashboard/presentation/screens/dashboard_screen_test.dart::el período arranca en el mes actual hasta hoy -->
<!-- test: test/features/dashboard/presentation/bloc/dashboard_cubit_test.dart::el estado inicial es el mes actual hasta hoy, por monto -->
- **WHEN** el usuario abre un dashboard el 6 de noviembre de 2026
- **THEN** el período es "01/11/2026  →  06/11/2026", la vista es "Por monto" y empieza la carga

---

### Requirement: Cargar el ranking y el resumen de la línea elegida
<!-- id: DashboardCubit.cargar -->
<!-- entities: TopProducto, ResumenVentas, LineaDashboard -->
<!-- enforced: DashboardCubit.cargar(), DashboardDatasourceImpl._top(), DashboardDatasourceImpl._resumen(), DashboardDatasourceImpl._finDelDia() -->

La carga DEBE pedir a la vez las dos consultas de su línea —telas: `top_productos` y `resumen_ventas`; apliques: `top_apliques` y `resumen_ventas_apliques`— con el mismo rango, y NO DEBE consultar las de la otra línea. El rango se envía como texto ISO 8601: `desde` es el inicio del primer día y `hasta` es el último instante del último día (23:59:59.999999), para que entre una venta registrada en el último segundo del día. Mientras carga DEBE verse un indicador de progreso y NO DEBE mostrarse el resumen.

#### Scenario: Dashboard de telas
<!-- test: test/features/dashboard/dashboard_test.dart::telas carga solo el top y el resumen de telas (2 RPC) -->
<!-- test: test/features/dashboard/infrastructure/repositories/dashboard_repository_impl_test.dart::telas y apliques no se cruzan -->
- **WHEN** se carga el dashboard de telas
- **THEN** se consultan solo `top_productos` y `resumen_ventas`, con el mismo rango

#### Scenario: Dashboard de apliques
<!-- test: test/features/dashboard/dashboard_test.dart::apliques carga solo el top y el resumen de apliques -->
<!-- test: test/features/dashboard/presentation/bloc/dashboard_cubit_test.dart::el dashboard de apliques no se cae si fallan las RPC de telas -->
- **WHEN** se carga el dashboard de apliques
- **THEN** se consultan solo `top_apliques` y `resumen_ventas_apliques`, y una falla en las de telas no lo afecta

#### Scenario: Rango enviado
<!-- test: test/features/dashboard/infrastructure/repositories/dashboard_repository_impl_test.dart::cada RPC recibe el mismo rango (desde, hasta) sin invertirlo -->
- **WHEN** el período es del 01/11/2026 al 06/11/2026
- **THEN** las consultas reciben desde "2026-11-01T00:00:00.000" y hasta "2026-11-06T23:59:59.999999"

#### Scenario: Cargando
<!-- test: test/features/dashboard/presentation/screens/dashboard_screen_test.dart::mientras carga muestra el progreso y no el resumen -->
- **WHEN** las consultas todavía no respondieron
- **THEN** se ve el indicador de progreso, sin tarjetas de resumen

---

### Requirement: Mostrar el resumen de ventas del período
<!-- id: DashboardDatasourceImpl._resumen -->
<!-- entities: ResumenVentas -->
<!-- enforced: DashboardDatasourceImpl._resumen(), _ResumenCards.build() -->

Con los datos cargados, el dashboard DEBE mostrar tres tarjetas, "Total", "Ganancias" y "Descuentos", con el monto en Bs y dos decimales. Un valor que llega nulo se muestra como 0.00.

#### Scenario: Resumen del período
<!-- test: test/features/dashboard/presentation/screens/dashboard_screen_test.dart::el resumen muestra total, ganancias y descuentos -->
- **WHEN** el resumen del período es total 1250.5, ganancias 300 y descuento 20
- **THEN** se ven "1250.50 Bs", "300.00 Bs" y "20.00 Bs" en sus tarjetas

---

### Requirement: Mostrar el ranking completo por total vendido
<!-- id: _TopProductos.build -->
<!-- entities: TopProducto -->
<!-- enforced: DashboardDatasourceImpl._top(), DashboardState.ordenados(), _TopProductos.build() -->

En la vista "Por monto" el dashboard DEBE listar todos los productos vendidos en el período en el orden que devuelve la consulta (mayor total primero), bajo el encabezado "N telas por total vendido" o "N apliques por total vendido". Cada fila DEBE mostrar su posición (las tres primeras con fondo oro, plata y bronce), el nombre en una línea, una barra proporcional al primero y el total en Bs con dos decimales. Un nombre nulo se muestra como "Sin nombre"; si el máximo es 0, las barras quedan vacías.

#### Scenario: Ranking por monto
<!-- test: test/features/dashboard/presentation/screens/dashboard_screen_test.dart::numera el ranking y las barras son proporcionales al primero -->
<!-- test: test/propiedades/dashboard_propiedades_test.dart::por monto deja el orden de la RPC -->
- **WHEN** el período tiene ventas de varias telas
- **THEN** se ven todas, numeradas desde 1 en el orden de la consulta, con barras proporcionales al primero

#### Scenario: Ventas en 0
<!-- test: test/features/dashboard/presentation/screens/dashboard_screen_test.dart::con ventas en 0 las barras quedan vacías (sin dividir por 0) -->
- **WHEN** todos los totales del ranking son 0
- **THEN** las barras se dibujan vacías

---

### Requirement: Ordenar el ranking por cantidad vendida
<!-- id: DashboardState.ordenados -->
<!-- entities: TopProducto, DashboardState -->
<!-- enforced: DashboardState.ordenados(), DashboardCubit.toggleVista(), _ToggleVista.build(), _TopProductos._cantidad() -->

La opción "Por cantidad" DEBE reordenar el mismo ranking de mayor a menor cantidad sin volver a consultar, con el encabezado "… por cantidad vendida", barras proporcionales a la mayor cantidad y la cantidad en metros ("mts") para telas o unidades ("uds") para apliques: sin decimales si es entera y con dos decimales si no. "Por monto" DEBE volver al orden de la consulta; tocar la opción ya elegida NO DEBE cambiar nada.

#### Scenario: Por cantidad en telas
<!-- test: test/features/dashboard/dashboard_test.dart::por cantidad reordena el ranking sin volver a consultar -->
<!-- test: test/features/dashboard/dashboard_test.dart::por cantidad: metros en telas -->
- **WHEN** en el dashboard de telas el usuario toca "Por cantidad"
- **THEN** el ranking queda ordenado por metros, mostrados como "12 mts" o "2.50 mts", sin nueva consulta

#### Scenario: Por cantidad en apliques
<!-- test: test/features/dashboard/dashboard_test.dart::por cantidad: unidades en apliques -->
- **WHEN** en el dashboard de apliques el usuario toca "Por cantidad"
- **THEN** las cantidades se muestran en "uds"

#### Scenario: Volver a por monto
<!-- test: test/features/dashboard/presentation/screens/dashboard_screen_test.dart::"Por monto" vuelve al orden por total después de "Por cantidad" -->
<!-- test: test/features/dashboard/presentation/bloc/dashboard_cubit_test.dart::por cantidad no reordena la lista original del estado -->
- **WHEN** el usuario toca "Por monto" después de "Por cantidad"
- **THEN** el ranking vuelve al orden por total de la consulta

#### Scenario: Tocar la vista elegida
<!-- test: test/features/dashboard/presentation/screens/dashboard_screen_test.dart::tocar la vista ya elegida no cambia nada -->
- **WHEN** el usuario toca la opción que ya está seleccionada
- **THEN** nada cambia

---

### Requirement: Avisar cuando no hubo ventas en el período
<!-- id: _TopProductos.build -->
<!-- entities: TopProducto -->
<!-- enforced: _TopProductos.build() -->

Si la consulta del ranking no devuelve filas, el dashboard DEBE mostrar "Sin ventas de telas en el período seleccionado" o "Sin ventas de apliques en el período seleccionado"; el resumen se muestra en 0.00.

#### Scenario: Período sin ventas
<!-- test: test/features/dashboard/dashboard_test.dart::apliques sin ventas muestra su aviso -->
- **WHEN** el período elegido no tiene ventas de apliques
- **THEN** se ve "Sin ventas de apliques en el período seleccionado"

---

### Requirement: Avisar y reintentar cuando la carga falla
<!-- id: DashboardCubit.cargar -->
<!-- entities: DashboardState -->
<!-- enforced: DashboardCubit.cargar(), _ErrorDeCarga.build() -->

Si falla cualquiera de las dos consultas, el dashboard DEBE descartar ranking y resumen (no mostrar datos de otro período ni el aviso de "Sin ventas"), conservar el período y la vista elegidos, y mostrar "No se pudieron cargar las ventas. Revisá la conexión." con un botón "Reintentar" que vuelve a cargar el mismo período.

#### Scenario: Sin conexión y reintento
<!-- test: test/features/dashboard/presentation/screens/dashboard_screen_test.dart::sin conexión avisa del error (no "Sin ventas") y reintentar recupera los datos -->
<!-- test: test/features/dashboard/presentation/bloc/dashboard_cubit_test.dart::si una RPC falla, cargar no lanza, deja de cargar y marca el error -->
- **WHEN** las consultas fallan y luego el usuario toca "Reintentar" con conexión
- **THEN** primero se ve el aviso sin resumen ni ranking, y después los datos del mismo período

---

### Requirement: Cambiar el período del dashboard
<!-- id: _RangoFechas.build -->
<!-- entities: DashboardState -->
<!-- triggers: Cargar el ranking y el resumen de la línea elegida -->
<!-- enforced: _RangoFechas.build(), DashboardCubit.cambiarRango() -->

Tocar el período DEBE abrir un selector de rango de fechas en español (aunque el dispositivo esté en otro idioma), entre el 1/1/2020 y hoy, con el período actual preseleccionado. Al confirmar un rango DEBE mostrarlo y volver a cargar las dos consultas con esas fechas, conservando la vista "Por monto"/"Por cantidad". Cancelar NO DEBE cambiar el período ni volver a consultar.

#### Scenario: Elegir un rango
<!-- test: test/features/dashboard/presentation/screens/dashboard_screen_test.dart::elegir un rango vuelve a consultar las 2 RPC con esas fechas -->
<!-- test: test/features/dashboard/dashboard_test.dart::cambiarRango consulta las dos RPC con el rango nuevo -->
<!-- test: integration_test/flujos/dashboard.dart::cambiar el período muestra las ventas de esas fechas -->
- **WHEN** el usuario elige del 01/10/2026 al 15/10/2026
- **THEN** el período muestra esas fechas y el ranking y el resumen corresponden a ese rango

#### Scenario: Conservar la vista
<!-- test: test/features/dashboard/presentation/bloc/dashboard_cubit_test.dart::cambiar de rango conserva la vista elegida -->
- **WHEN** la vista es "Por cantidad" y se cambia el período
- **THEN** el nuevo ranking se muestra por cantidad

#### Scenario: Cancelar
<!-- test: test/features/dashboard/presentation/screens/dashboard_screen_test.dart::cancelar conserva el período y no vuelve a consultar -->
- **WHEN** el usuario abre el selector y lo cancela
- **THEN** el período no cambia y no se consulta de nuevo

#### Scenario: Idioma del selector
<!-- test: test/features/dashboard/presentation/screens/dashboard_screen_test.dart::está en español aunque el dispositivo no lo esté -->
- **WHEN** el dispositivo está en inglés
- **THEN** el selector de fechas se muestra en español

---

### Requirement: Rankear las telas vendidas en un rango
<!-- id: 20261020000000_idempotencia_y_venta_telas.sql:top_productos -->
<!-- entities: detalle_ventas, ventas, telas -->
<!-- enforced: 20261020000000_idempotencia_y_venta_telas.sql:top_productos -->

`top_productos(desde, hasta)` DEBE devolver una fila por tela vendida, sumando las líneas de `detalle_ventas` de las ventas de telas de todas las sucursales cuya `fecha`, comparada como texto, está entre `desde` y `hasta` inclusive. Cada fila DEBE traer `nombre` (el nombre actual de la tela; el de la línea solo si la tela no existe), `total_vendido` (suma de totales) y `total_cantidad` (suma de metros), ambas nunca nulas (0 si no hay valores), ordenadas por `total_vendido` de mayor a menor. Agrupa por tela, no por nombre, e incluye telas dadas de baja.

#### Scenario: Rango con ventas
<!-- test: supabase/tests/database/06_dashboard.test.sql::top_productos: agrupa por tela con su nombre actual, suma total y cantidad del rango y ordena por total -->
- **WHEN** en el rango se vendieron líneas de dos telas
- **THEN** devuelve una fila por tela con sus sumas, la de mayor total primero

#### Scenario: Rango sin ventas
<!-- test: supabase/tests/database/06_dashboard.test.sql::top_productos: sin ventas en el rango no devuelve filas -->
- **WHEN** no hay ventas de telas en el rango
- **THEN** no devuelve filas

#### Scenario: Tela renombrada
<!-- test: supabase/tests/database/06_dashboard.test.sql::top_productos: una tela renombrada conserva todo su historial con el nombre nuevo -->
- **WHEN** una tela con ventas se renombra
- **THEN** todo su historial aparece en una sola fila con el nombre nuevo

#### Scenario: Comparación como texto
<!-- test: supabase/tests/database/06_dashboard.test.sql::top_productos: compara fecha como texto ("…T23:59:59" deja afuera "…T23:59:59.500") -->
- **WHEN** `hasta` termina en "T23:59:59" y hay una venta a las "T23:59:59.500" de ese día
- **THEN** esa venta queda fuera del ranking

---

### Requirement: Rankear los apliques vendidos en un rango
<!-- id: 20261006000000_top_apliques.sql:top_apliques -->
<!-- entities: detalle_ventas_apliques, ventas_apliques, apliques -->
<!-- enforced: 20261006000000_top_apliques.sql:top_apliques -->

`top_apliques(desde, hasta)` DEBE devolver las mismas columnas que `top_productos`, con una fila por aplique vendido: suma las líneas de `detalle_ventas_apliques` de todos los colores y sucursales, de las ventas de apliques cuya `fecha`, comparada como texto, está entre `desde` y `hasta` inclusive. `nombre` DEBE ser el nombre actual de la tabla `apliques` (el de la línea solo si el aplique no existe), y las filas DEBEN ir de mayor a menor `total_vendido`.

#### Scenario: Rango con ventas
<!-- test: supabase/tests/database/06_dashboard.test.sql::top_apliques: agrupa por aplique con el nombre de la tabla apliques, suma todos los colores y ordena por total -->
- **WHEN** un aplique se vendió en dos colores dentro del rango
- **THEN** aparece una sola vez con la suma de ambos colores y el nombre de la tabla de apliques

#### Scenario: Rango sin ventas
<!-- test: supabase/tests/database/06_dashboard.test.sql::top_apliques: sin ventas en el rango no devuelve filas -->
- **WHEN** no hay ventas de apliques en el rango
- **THEN** no devuelve filas

#### Scenario: Aplique renombrado
<!-- test: supabase/tests/database/06_dashboard.test.sql::top_apliques: un aplique renombrado conserva todo su historial con el nombre nuevo -->
- **WHEN** un aplique con ventas se renombra
- **THEN** todo su historial aparece en una sola fila con el nombre nuevo

---

### Requirement: Resumir las ventas de telas de un rango
<!-- id: 20260925000000_prod_schema.sql:resumen_ventas -->
<!-- entities: ventas -->
<!-- enforced: 20260925000000_prod_schema.sql:resumen_ventas -->

`resumen_ventas(desde, hasta)` DEBE devolver una sola fila con la suma de `total`, `ganancias` y `descuento` de las ventas de telas (cabeceras) de todas las sucursales cuya `fecha`, comparada como texto, está entre `desde` y `hasta` inclusive; sin ventas, la fila DEBE venir en 0 (no nula).

#### Scenario: Rango con ventas
<!-- test: supabase/tests/database/06_dashboard.test.sql::resumen_ventas: suma total, ganancias y descuento de las ventas del rango -->
- **WHEN** hay ventas de telas en el rango
- **THEN** devuelve la suma de sus totales, ganancias y descuentos

#### Scenario: Rango sin ventas
<!-- test: supabase/tests/database/06_dashboard.test.sql::resumen_ventas: sin ventas devuelve una fila en 0 (no NULL) -->
- **WHEN** no hay ventas de telas en el rango
- **THEN** devuelve una fila con 0, 0 y 0

#### Scenario: Hasta sin hora
<!-- test: supabase/tests/database/06_dashboard.test.sql::resumen_ventas: un hasta sin hora deja afuera todo ese día (por eso la app manda el último instante) -->
- **WHEN** `hasta` es solo la fecha ("2187-03-31")
- **THEN** las ventas de ese día quedan fuera del resumen

---

### Requirement: Resumir las ventas de apliques de un rango
<!-- id: 20260925000000_prod_schema.sql:resumen_ventas_apliques -->
<!-- entities: ventas_apliques -->
<!-- enforced: 20260925000000_prod_schema.sql:resumen_ventas_apliques -->

`resumen_ventas_apliques(desde, hasta)` DEBE devolver una sola fila con la suma de `total`, `ganancias` y `descuento` de las ventas de apliques de todas las sucursales cuya `fecha`, comparada como texto, está entre `desde` y `hasta` inclusive; sin ventas, la fila DEBE venir en 0.

#### Scenario: Rango con ventas
<!-- test: supabase/tests/database/06_dashboard.test.sql::resumen_ventas_apliques: suma total, ganancias y descuento de las ventas del rango -->
- **WHEN** hay ventas de apliques en el rango
- **THEN** devuelve la suma de sus totales, ganancias y descuentos

#### Scenario: Rango sin ventas
<!-- test: supabase/tests/database/06_dashboard.test.sql::resumen_ventas_apliques: sin ventas devuelve una fila en 0 (no NULL) -->
- **WHEN** no hay ventas de apliques en el rango
- **THEN** devuelve una fila con 0, 0 y 0

---

### Invariant: Las consultas del dashboard solo leen
<!-- entities: top_productos, top_apliques, resumen_ventas, resumen_ventas_apliques -->
<!-- enforced: 20261020000000_idempotencia_y_venta_telas.sql:top_productos, 20261006000000_top_apliques.sql:top_apliques, 20260925000000_prod_schema.sql:resumen_ventas, 20260925000000_prod_schema.sql:resumen_ventas_apliques -->
<!-- verified_by: supabase/tests/database/06_dashboard.test.sql::las cuatro RPC del dashboard son STABLE (solo leen) -->

Las cuatro consultas del dashboard DEBEN ser funciones SQL `STABLE` sin efectos: abrir o recargar un dashboard NO DEBE modificar ningún dato.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Las consultas del dashboard devuelven columnas fijas
<!-- entities: TopProducto, ResumenVentas -->
<!-- enforced: 20261020000000_idempotencia_y_venta_telas.sql:top_productos, 20261006000000_top_apliques.sql:top_apliques, 20260925000000_prod_schema.sql:resumen_ventas, 20260925000000_prod_schema.sql:resumen_ventas_apliques, DashboardDatasourceImpl._top(), DashboardDatasourceImpl._resumen() -->
<!-- verified_by: supabase/tests/database/06_dashboard.test.sql::top_productos(desde text, hasta text) devuelve nombre, total_vendido, total_cantidad -->
<!-- verified_by: supabase/tests/database/06_dashboard.test.sql::top_apliques(desde text, hasta text) devuelve las mismas columnas que top_productos -->
<!-- verified_by: supabase/tests/database/06_dashboard.test.sql::resumen_ventas(desde text, hasta text) devuelve total, ganancias, descuento -->
<!-- verified_by: supabase/tests/database/06_dashboard.test.sql::resumen_ventas_apliques(desde text, hasta text) devuelve total, ganancias, descuento -->

`top_productos` y `top_apliques` DEBEN recibir `desde` y `hasta` como texto y devolver `(nombre text, total_vendido numeric, total_cantidad numeric)`; `resumen_ventas` y `resumen_ventas_apliques` DEBEN recibir lo mismo y devolver `(total numeric, ganancias numeric, descuento numeric)`. Las otras apps las llaman por estos nombres.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Solo un usuario con sesión obtiene datos del dashboard
<!-- entities: anon, authenticated -->
<!-- enforced: 20261006000000_top_apliques.sql:REVOKE ALL ON FUNCTION top_apliques FROM PUBLIC, anon, 20261004000000_solo_usuarios_logueados.sql:REVOKE ALL ON ALL TABLES FROM anon -->

Sin sesión, ninguna de las cuatro consultas DEBE entregar datos: `top_apliques` solo la puede ejecutar un usuario con sesión, y las otras tres, aunque el rol anónimo todavía puede invocarlas, fallan porque ese rol no puede leer las tablas de ventas.

> Last verified: 2026-11-06 (commit 1d15233)

<!-- revisar: 20261004000000_solo_usuarios_logueados.sql:40 — anon conserva EXECUTE (vía PUBLIC) sobre top_productos, resumen_ventas y resumen_ventas_apliques; está como todo() en 01_rls_y_permisos.test.sql:198. -->

<!-- uncertainty: el ranking y el resumen suman todas las sucursales; no hay filtro por sucursal en la pantalla ni en las consultas. -->
<!-- uncertainty: el orden "Por cantidad" usa el sort de Dart, que no garantiza estabilidad: productos con la misma cantidad pueden no conservar el orden por monto. -->
