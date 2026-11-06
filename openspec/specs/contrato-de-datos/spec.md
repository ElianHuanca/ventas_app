---
description: Reglas transversales de la base Postgres/Supabase que este repo es dueño (las comparten Flutter, Android, iOS y la web). Cubre acceso solo con sesión (RLS solo_logueados_*, anon sin acceso salvo las vistas *_web), baja lógica y qué tablas admiten DELETE, restricciones CHECK y UNIQUE, el mecanismo de idempotencia de las escrituras (operaciones_aplicadas y la clave que genera la app), el formato de fecha como texto ISO 8601 y lo que publican (y nunca publican) las vistas públicas de la web.
---

# Spec: contrato-de-datos

> Extraído automáticamente por spec-miner. Última extracción: 2026-11-06.
> Fuentes: supabase/migrations/*.sql (10 migraciones, de 20260925000000_prod_schema.sql a 20261021000000_fotos_de_productos.sql), supabase/landing.sql, lib/features/shared/clave_de_operacion.dart, supabase/tests/database/{01,05,07,09,10}_*.test.sql
> Last verified: 2026-11-06 (commit 1d15233)

---

### Requirement: Rechazar lecturas y escrituras sin sesión
<!-- id: 20261004000000_solo_usuarios_logueados.sql:solo_logueados_* -->
<!-- entities: anon, authenticated -->
<!-- enforced: 20261004000000_solo_usuarios_logueados.sql:solo_logueados_*, 20261004000000_solo_usuarios_logueados.sql:REVOKE ALL FROM anon, 20261020000000_idempotencia_y_venta_telas.sql:REVOKE EXECUTE FROM PUBLIC, anon -->

Un cliente sin sesión (rol `anon`) NO DEBE poder leer, insertar, modificar ni borrar ninguna tabla de `public`, ni usar sus secuencias, ni obtener datos de ninguna RPC; solo DEBE poder leer las vistas `*_web`. Un usuario con sesión (rol `authenticated`) DEBE poder leer, insertar y modificar todas las tablas y ejecutar todas las RPC de las apps, sin roles ni restricciones por fila ("logueado = acceso total").

#### Scenario: Lectura sin sesión
<!-- test: supabase/tests/database/01_rls_y_permisos.test.sql::anon no tiene ningún privilegio sobre las tablas -->
- **WHEN** un cliente sin sesión consulta cualquier tabla
- **THEN** la base responde permiso denegado (42501)

#### Scenario: RPC sin sesión
<!-- test: supabase/tests/database/01_rls_y_permisos.test.sql::anon recibe permiso denegado al llamar %s -->
- **WHEN** un cliente sin sesión llama a una RPC
- **THEN** recibe permiso denegado

#### Scenario: Usuario con sesión
<!-- test: supabase/tests/database/01_rls_y_permisos.test.sql::authenticated tiene SELECT, INSERT y UPDATE en todas las tablas -->
- **WHEN** un usuario con sesión lee, inserta o modifica cualquier tabla
- **THEN** la operación se permite

<!-- revisar: 20261004000000_solo_usuarios_logueados.sql:40 el REVOKE FROM anon no saca el EXECUTE de PUBLIC: anon todavía puede ejecutar top_productos, resumen_ventas y resumen_ventas_apliques (no obtiene datos porque no tiene SELECT en las tablas); todo() en 01_rls_y_permisos.test.sql -->

---

### Invariant: Toda tabla tiene RLS y la política solo_logueados
<!-- entities: authenticated -->
<!-- enforced: 20261004000000_solo_usuarios_logueados.sql:solo_logueados_*, 20261020000000_idempotencia_y_venta_telas.sql:solo_logueados_operaciones_aplicadas, 20261021000000_fotos_de_productos.sql:solo_logueados_aplique_fotos -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::toda tabla tiene su política solo_logueados_<tabla> (FOR ALL TO authenticated USING true WITH CHECK true) -->

Cada una de las 18 tablas de `public` (aplique_colores, aplique_fotos, apliques, categorias, colores, detalle_produccion, detalle_ventas, detalle_ventas_apliques, inventario, operaciones_aplicadas, producciones, sucursales, tela_colores, tela_fotos, tela_sucursales, telas, ventas, ventas_apliques) DEBE tener RLS activado y exactamente una política, `solo_logueados_<tabla>` (FOR ALL TO authenticated USING true WITH CHECK true). Sin esa política una tabla nueva devuelve vacío en silencio a la app.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Sin borrado físico salvo ventas de telas y sus líneas
<!-- entities: Venta, DetalleVenta -->
<!-- enforced: 20261003000100_integridad_stock_y_ventas.sql:REVOKE DELETE, 20261003000100_integridad_stock_y_ventas.sql:REVOKE TRUNCATE, 20261020000000_idempotencia_y_venta_telas.sql:GRANT operaciones_aplicadas, 20261021000000_fotos_de_productos.sql:GRANT aplique_fotos -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::DELETE físico solo en ventas y detalle_ventas -->

`anon` y `authenticated` NO DEBEN tener DELETE sobre ninguna tabla salvo `ventas` y `detalle_ventas`, ni TRUNCATE sobre ninguna. Borrar una venta de telas DEBE borrar sus líneas (FK `detalle_ventas_idventa_fkey` ON DELETE CASCADE). Las claves de `operaciones_aplicadas` no las borra nadie.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Baja lógica con la columna activo
<!-- entities: Sucursal, Tela, Color, Aplique, Categoria, Inventario, TelaColor, ApliqueColor, TelaSucursal, TelaFoto, ApliqueFoto -->
<!-- enforced: 20260925000000_prod_schema.sql:activo DEFAULT true NOT NULL, 20261003000100_integridad_stock_y_ventas.sql:REVOKE DELETE, SucursalesDatasourceImpl.deleteSucursal(), ApliquesDatasourceImpl.setColorAplique() -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::DELETE físico solo en ventas y detalle_ventas -->

Dar de baja una fila de `sucursales`, `telas`, `colores`, `apliques`, `categorias`, `inventario`, `tela_colores`, `aplique_colores`, `tela_sucursales`, `tela_fotos` o `aplique_fotos` DEBE hacerse con `activo = false` (columna NOT NULL, default true), nunca con DELETE. Lo que se ofrece para vender, fabricar o publicar DEBE filtrar `activo = true`; las pantallas de gestión de apliques y telas listan también los inactivos.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Montos, cantidades y stock no negativos
<!-- entities: Inventario, DetalleVenta, DetalleVentaAplique, Produccion, Tela, Aplique, Venta, VentaAplique -->
<!-- enforced: 20261003000100_integridad_stock_y_ventas.sql:inventario_stock_no_negativo, 20261003000100_integridad_stock_y_ventas.sql:detalle_ventas_apliques_montos_check, 20261003000100_integridad_stock_y_ventas.sql:detalle_ventas_montos_check, 20261003000100_integridad_stock_y_ventas.sql:telas_precios_no_negativos, 20261003000100_integridad_stock_y_ventas.sql:apliques_costo_no_negativo, 20261003000100_integridad_stock_y_ventas.sql:ventas_descuento_no_negativo, 20261003000100_integridad_stock_y_ventas.sql:ventas_apliques_montos_check, 20260925000000_prod_schema.sql:detalle_produccion_cantidad_check -->
<!-- verified_by: supabase/tests/database/05_restricciones.test.sql::inventario: no acepta stock negativo -->

La base DEBE rechazar: `inventario.stock` < 0; en `detalle_ventas` cantidad <= 0 o precio < 0; en `detalle_ventas_apliques` cantidad <= 0, precio < 0 o total < 0; en `detalle_produccion` cantidad <= 0; en `telas` cualquier precio (por metro, mayor, rollo, compra) < 0; en `apliques` costo de fabricación < 0; en `ventas` descuento < 0; en `ventas_apliques` total < 0 o descuento < 0. No hay CHECK sobre `ventas.total` ni sobre las ganancias.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Unicidad de cabeceras, líneas y vínculos
<!-- entities: Venta, VentaAplique, ProduccionCabecera, DetalleVenta, DetalleVentaAplique, Produccion, Inventario, ApliqueColor, TelaColor, TelaSucursal -->
<!-- enforced: 20261003000100_integridad_stock_y_ventas.sql:ventas_sucursal_dia_key, 20261004000100_venta_apliques_por_dia.sql:ventas_apliques_sucursal_dia_key, 20261003000100_integridad_stock_y_ventas.sql:producciones_sucursal_fecha_key, 20261003000100_integridad_stock_y_ventas.sql:detalle_ventas_linea_key, 20261004000100_venta_apliques_por_dia.sql:detalle_ventas_apliques_linea_key, 20261003000100_integridad_stock_y_ventas.sql:detalle_produccion_linea_key, 20260925000000_prod_schema.sql:inventario_pkey -->
<!-- verified_by: supabase/tests/database/05_restricciones.test.sql::ventas: una sola venta de telas por sucursal y día (aunque cambie la hora) -->

La base DEBE garantizar una venta de telas y una de apliques por sucursal y día (`left(fecha, 10)`), una producción por sucursal y fecha, una línea por (venta, tela, precio), por (venta, aplique, color, precio) y por (producción, aplique, color), una fila de inventario por (sucursal, aplique, color) y un vínculo por (aplique, color), (tela, color) y (tela, sucursal). También son únicos `colores.nombre`, `categorias.nombre`, `categorias.slug`, `sucursales.slug` y `telas.slug`.

> Last verified: 2026-11-06 (commit 1d15233)

<!-- revisar: supabase/ventas_apliques.sql:37 copió ventas de apliques con ids 1001–1017 sin setval: ventas_apliques_id_seq arranca en 1 y, al llegar a 1001, crear_venta_apliques fallará por duplicate key una vez por id ocupado (todo() en 05_restricciones.test.sql) -->

---

### Invariant: Fechas de venta como texto ISO 8601
<!-- entities: Venta, VentaAplique, ProduccionCabecera -->
<!-- enforced: 20260925000000_prod_schema.sql:ventas.fecha, 20260925000000_prod_schema.sql:ventas_apliques.fecha, 20261003000100_integridad_stock_y_ventas.sql:ventas_sucursal_dia_key, VentasDatasourceImpl.registrarVentaTelas(), VentasApliquesDatasourceImpl.createVentaAplique() -->
<!-- verified_by: supabase/tests/database/08_inventario_con_ventas.test.sql::compara fecha como texto: hasta "…T23:59:59" deja afuera "…T23:59:59.500" -->

`ventas.fecha` y `ventas_apliques.fecha` DEBEN ser texto NOT NULL con fecha y hora ISO 8601 (la app manda la hora local sin zona, con fracción de segundo); el día son sus primeros 10 caracteres y las RPC de lectura comparan `fecha` como texto contra `desde`/`hasta`. `producciones.fecha` es de tipo `date`. Los montos son `numeric`.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Las RPC corren con los permisos de quien llama
<!-- entities: authenticated -->
<!-- enforced: 20261020000000_idempotencia_y_venta_telas.sql:SET search_path = public, 20261003000100_integridad_stock_y_ventas.sql:SET search_path = public -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::las RPC son SECURITY INVOKER: corren con los permisos de quien llama y no saltan RLS -->

Toda función de `public` (salvo el disparador `rls_auto_enable`, que nadie de la API puede ejecutar) DEBE ser SECURITY INVOKER y fijar su `search_path`. Las únicas funciones son las 11 RPC conocidas: crear_venta_apliques, registrar_produccion, registrar_venta_telas, borrar_detalle_venta, registrar_detalle_venta, incrementar_venta, top_productos, top_apliques, resumen_ventas, resumen_ventas_apliques e inventario_con_ventas.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: La clave de operación es opcional y va al final
<!-- entities: OperacionAplicada -->
<!-- enforced: 20261020000000_idempotencia_y_venta_telas.sql:crear_venta_apliques, 20261020000000_idempotencia_y_venta_telas.sql:registrar_produccion, 20261020000000_idempotencia_y_venta_telas.sql:registrar_venta_telas -->
<!-- verified_by: supabase/tests/database/09_contrato.test.sql::%s: p_id_operacion es opcional (DEFAULT NULL, al final): lo llaman sin ella Android, iOS y los Flutter viejos -->

`crear_venta_apliques`, `registrar_produccion` y `registrar_venta_telas` DEBEN aceptar `p_id_operacion uuid DEFAULT NULL` como último parámetro; las demás firmas, nombres de parámetros, columnas, tipos y claves JSON que leen Flutter, Android, iOS y la web están fijados por `09_contrato.test.sql` y NO DEBEN cambiar sin actualizar a esas apps.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Requirement: Aplicar una sola vez cada clave de operación
<!-- id: 20261020000000_idempotencia_y_venta_telas.sql:operaciones_aplicadas -->
<!-- entities: OperacionAplicada, Venta, VentaAplique, ProduccionCabecera -->
<!-- enforced: 20261020000000_idempotencia_y_venta_telas.sql:operaciones_aplicadas, 20261020000000_idempotencia_y_venta_telas.sql:crear_venta_apliques, 20261020000000_idempotencia_y_venta_telas.sql:registrar_produccion, 20261020000000_idempotencia_y_venta_telas.sql:registrar_venta_telas -->

Cuando `crear_venta_apliques`, `registrar_produccion` o `registrar_venta_telas` reciben una clave, la base DEBE guardarla en `operaciones_aplicadas` (id, rpc, resultado = id de la venta o producción, creada) en la misma transacción que la escritura. Con una clave ya aplicada por la misma RPC DEBE devolver el resultado de entonces sin aplicar nada, aunque el contenido sea otro. Si la escritura falla, la clave DEBE revertirse con todo y el reintento se aplica. Una clave ya usada por otra RPC DEBE dar error "La clave de operación <id> ya se usó en <rpc>" (HINT `operacion_de_otra_rpc`) sin aplicar nada. Sin clave, cada llamada DEBE aplicarse (como las apps viejas, Android e iOS). Un reintento que llega mientras el primero sigue en curso DEBE esperar a que termine. Las validaciones de contenido de `registrar_venta_telas` y el chequeo "sin líneas" de `crear_venta_apliques` se hacen antes de mirar la clave.

#### Scenario: Misma clave dos veces
<!-- test: supabase/tests/database/10_idempotencia.test.sql::y no vuelve a aplicar nada: stock, venta del día, líneas y claves iguales -->
- **WHEN** llega dos veces la misma clave a la misma RPC
- **THEN** la segunda devuelve el mismo id y no cambia stock, totales ni líneas

#### Scenario: Misma clave con otro contenido
<!-- test: supabase/tests/database/10_idempotencia.test.sql::con la misma clave y otro contenido también devuelve lo de la primera vez -->
- **WHEN** la clave ya aplicada llega con otro contenido
- **THEN** devuelve lo de la primera vez sin aplicar el contenido nuevo

#### Scenario: Escritura fallida
<!-- test: supabase/tests/database/10_idempotencia.test.sql::la venta rechazada no deja su clave guardada -->
- **WHEN** la escritura con una clave nueva falla (p. ej. sin stock)
- **THEN** la clave no queda guardada y un reintento con ella se aplica

#### Scenario: Clave de otra RPC
<!-- test: supabase/tests/database/10_idempotencia.test.sql::crear_venta_apliques rechaza una clave de registrar_venta_telas (HINT operacion_de_otra_rpc) -->
- **WHEN** se usa en una RPC una clave que ya aplicó otra
- **THEN** da error con HINT operacion_de_otra_rpc y no aplica nada

#### Scenario: Sin clave
<!-- test: supabase/tests/database/10_idempotencia.test.sql::sin clave cada llamada se aplica (dos llamadas = dos ventas sumadas) -->
- **WHEN** se llama dos veces sin clave
- **THEN** se aplica dos veces

#### Scenario: Reintentos cruzados
<!-- test: concurrencia/venta_telas_test.dart::el mismo envío (misma clave) desde $cantidadDispositivos dispositivos a la vez -->
- **WHEN** 8 clientes mandan a la vez la misma clave
- **THEN** se aplica una sola vez y todos reciben el mismo resultado

---

### Requirement: Generar la clave de operación por envío en la app
<!-- id: ClaveDeOperacion.para -->
<!-- entities: ClaveDeOperacion -->
<!-- enforced: ClaveDeOperacion.para(), ClaveDeOperacion.descartar(), clave_de_operacion.uuidV4() -->

La app DEBE generar la clave como un uuid v4 (122 bits de un generador seguro; minúsculas con guiones, versión 4 y variante RFC). Para cada envío DEBE devolver la misma clave mientras el contenido (listas, mapas y valores, comparados por contenido en profundidad) sea igual al del último envío y no se haya descartado; si el contenido cambió DEBE generar otra (volver a un contenido anterior después de otro NO recupera su clave). Después de un envío exitoso DEBE descartarse: el siguiente lleva otra clave aunque sea igual. Cada formulario que guarda tiene su propia clave.

#### Scenario: Mismo envío
<!-- test: test/features/shared/clave_de_operacion_test.dart::ClaveDeOperacion > el mismo envío (aunque sean otros objetos con el mismo contenido) lleva la misma clave: es el reintento -->
- **WHEN** se pide la clave dos veces para envíos con el mismo contenido
- **THEN** es la misma

#### Scenario: Volver a un envío anterior
<!-- test: test/features/shared/clave_de_operacion_test.dart::ClaveDeOperacion > volver a un envío anterior después de otro no recupera su clave -->
- **WHEN** se pide para A, luego para B y otra vez para A
- **THEN** la última clave es nueva

#### Scenario: Después de descartar
<!-- test: test/features/shared/clave_de_operacion_test.dart::ClaveDeOperacion > después de descartar, el mismo envío lleva otra clave -->
- **WHEN** el envío salió bien y se repite el mismo contenido
- **THEN** lleva otra clave

<!-- revisar: si la respuesta se perdió y el usuario cambia el carrito antes de reintentar, es otro envío con otra clave: si el primero había llegado, quedan aplicados los dos (riesgo aceptado en CLAUDE.md) -->

---

### Requirement: Publicar el top de telas sin montos
<!-- id: 20260925000000_prod_schema.sql:top_telas_web -->
<!-- entities: Tela, DetalleVenta, TelaFoto -->
<!-- enforced: 20260925000000_prod_schema.sql:top_telas_web, landing.sql:top_telas_web -->

`top_telas_web` DEBE publicar, sin sesión y solo para leer, hasta 6 telas activas con al menos un precio mayor a 0, ordenadas por lo vendido históricamente (suma de `detalle_ventas.total` agrupada por tela, no por nombre), con `posicion`, id, nombre, slug, descripción, ancho, `precio_metro`, `precio_mayor` y `precio_rollo` (NULL si el precio es 0: no se vende en esa modalidad) y `foto` (la primera foto activa por id). NO DEBE publicar el monto vendido ni `precxcompra`.

#### Scenario: Renombrar no parte el historial
<!-- test: supabase/tests/database/07_vistas_web.test.sql::top_telas_web: una tela con líneas de distinto nombre aparece una sola vez -->
- **WHEN** una tela tiene líneas vendidas con distintos nombres
- **THEN** aparece una sola vez en el top

#### Scenario: Sin montos ni costo
<!-- test: supabase/tests/database/07_vistas_web.test.sql::top_telas_web no expone el monto del ranking -->
- **WHEN** la web lee el top
- **THEN** recibe la posición pero no el monto ni el precio de compra

---

### Requirement: Publicar las sucursales activas
<!-- id: 20260925000000_prod_schema.sql:sucursales_web -->
<!-- entities: Sucursal -->
<!-- enforced: 20260925000000_prod_schema.sql:sucursales_web, landing.sql:sucursales_web -->

`sucursales_web` DEBE publicar, sin sesión y solo para leer, id, nombre, slug, dirección, latitud y longitud de las sucursales activas, ordenadas por id. Una sucursal dada de baja NO DEBE publicarse, y la vista NO DEBE permitir crear ni modificar sucursales.

#### Scenario: Sucursal dada de baja
<!-- test: supabase/tests/database/07_vistas_web.test.sql::sucursales_web: no publica una sucursal dada de baja (activo = false) -->
- **WHEN** una sucursal tiene activo = false
- **THEN** no aparece en la vista

#### Scenario: Escritura por la vista
<!-- test: supabase/tests/database/01_rls_y_permisos.test.sql::anon no puede modificar sucursales a través de sucursales_web -->
- **WHEN** un cliente sin sesión intenta modificar o crear por la vista
- **THEN** se rechaza

---

### Requirement: Publicar el catálogo de telas sin costos
<!-- id: 20261021000000_fotos_de_productos.sql:catalogo_telas_web -->
<!-- entities: Tela, TelaColor, Color, TelaFoto -->
<!-- enforced: 20261021000000_fotos_de_productos.sql:catalogo_telas_web, landing.sql:catalogo_telas_web -->

`catalogo_telas_web` DEBE publicar, sin sesión y solo para leer, todas las telas activas (también sin precio) ordenadas por nombre sin mayúsculas, con id, nombre, slug, descripción, ancho, precios por modalidad (NULL si son 0), `foto` (la primera activa por id), `colores` (jsonb `[{nombre, hex}]` de vínculos y colores activos, por nombre sin mayúsculas) y `fotos` (jsonb con las URL activas por id). NO DEBE publicar `precxcompra` ni montos vendidos.

#### Scenario: Catálogo de telas
<!-- test: supabase/tests/database/07_vistas_web.test.sql::catalogo_telas_web: no publica telas inactivas -->
- **WHEN** una tela está inactiva
- **THEN** no aparece; las activas salen con colores y fotos activos y sin precio de compra

---

### Requirement: Publicar el catálogo de apliques sin costos
<!-- id: 20261021000000_fotos_de_productos.sql:catalogo_apliques_web -->
<!-- entities: Aplique, ApliqueColor, Color, ApliqueFoto -->
<!-- enforced: 20261021000000_fotos_de_productos.sql:catalogo_apliques_web, landing.sql:catalogo_apliques_web -->

`catalogo_apliques_web` DEBE publicar, sin sesión y solo para leer, los apliques activos ordenados por nombre sin mayúsculas, con id, nombre, tamanio, ancho_cm, alto_cm, `colores` (vínculos y colores activos), `foto` (la primera activa por id) y `fotos`. NO DEBE publicar `costo_fabricacion` ni stock ni ventas.

#### Scenario: Catálogo de apliques
<!-- test: supabase/tests/database/07_vistas_web.test.sql::catalogo_apliques_web no expone costo_fabricacion -->
- **WHEN** la web lee el catálogo de apliques
- **THEN** recibe los apliques activos sin el costo de fabricación

#### Scenario: Fotos
<!-- test: supabase/tests/database/07_vistas_web.test.sql::catalogo_apliques_web: fotos activas por id y foto = la primera -->
- **WHEN** un aplique tiene fotos activas e inactivas
- **THEN** `fotos` lleva solo las activas por id y `foto` es la primera

---

### Invariant: Las vistas públicas son de solo lectura
<!-- entities: anon -->
<!-- enforced: 20261003000100_integridad_stock_y_ventas.sql:REVOKE ALL ON *_web, 20261004000000_solo_usuarios_logueados.sql:GRANT SELECT ON *_web -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::las vistas *_web son de solo lectura (corren como su dueño: con escritura serían una puerta a las tablas) -->

Las únicas vistas de `public` DEBEN ser `top_telas_web`, `sucursales_web`, `catalogo_telas_web` y `catalogo_apliques_web`; `anon` y `authenticated` solo DEBEN tener SELECT sobre ellas. Corren con los permisos de su dueño, por eso funcionan aunque `anon` no tenga acceso a las tablas.

> Last verified: 2026-11-06 (commit 1d15233)

<!-- uncertainty: rls_auto_enable (20260925000000_prod_schema.sql) es una función de disparador de eventos que activa RLS en tablas nuevas, pero ninguna migración crea el EVENT TRIGGER que la usaría; no se describe como garantía -->
<!-- uncertainty: top_telas_web y sucursales_web solo están en el dump de producción y en landing.sql (no en migraciones posteriores); catalogo_*_web están en landing.sql y en migraciones: si difieren, manda la última aplicada -->
<!-- uncertainty: authenticated tiene SELECT/INSERT/UPDATE sobre operaciones_aplicadas (lo necesitan las RPC SECURITY INVOKER): un cliente con sesión podría alterar una clave o su resultado -->
<!-- deferred: supabase/tests/database/09_contrato.test.sql (solo leídas las aserciones de p_id_operacion), supabase/tests/database/06_dashboard.test.sql -->
