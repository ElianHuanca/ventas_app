---
description: Catálogo de telas (listado, búsqueda por nombre, alta, modificación, baja y reactivación lógicas, validación de nombre y precios por modalidad, donde 0 significa que no se vende así) y colores vinculados por tela (tela_colores).
---

# Spec: telas

> Extraído automáticamente por spec-miner. Última extracción: 2026-11-06.
> Fuente: lib/features/telas/ (tela.dart, telas_datasource_impl.dart, tela_mapper.dart, telas_bloc.dart, tela_bloc.dart, tela_form_cubit.dart, tela_colores_cubit.dart, telas_screen.dart, tela_screen.dart, tela_colores_screen.dart), lib/features/shared/widgets/producto_colores_list.dart, lib/features/shared/ (carga_fallida.dart, show_snackbar.dart), lib/config/router/app_router.dart, supabase/migrations/20260925000000_prod_schema.sql, supabase/migrations/20261003000100_integridad_stock_y_ventas.sql, supabase/migrations/20261021000000_fotos_de_productos.sql
> Last verified: 2026-11-08 (change ordenar-colores-de-la-tela-a-z, sobre 4c0196b)

---

### Requirement: Listar el catálogo de telas
<!-- id: TelasBloc._onLoadRequested -->
<!-- entities: Tela, telas -->
<!-- enforced: TelasBloc._onLoadRequested(), TelasDatasourceImpl.getTelas(), TelasScreen._buildBody(), TelasScreen._telaCard() -->

La pantalla "Telas" (con menú lateral) DEBE listar todas las telas, activas y dadas de baja, ordenadas por nombre sin distinguir mayúsculas. Cada tarjeta DEBE mostrar el nombre y cuatro precios: "X Menor: … Bs", "X Mayor: … Bs", "X Rollo: … Bs" y "Compra: … Bs". Las telas dadas de baja DEBEN llevar la marca "Inactivo" y el nombre atenuado. Mientras carga se ve un indicador de progreso a pantalla completa. Si la carga falla, la lista queda vacía como si no hubiera telas.

#### Scenario: Catálogo con telas activas e inactivas
<!-- test: test/features/telas/presentation/screens/telas_screen_test.dart::muestra todas las telas (también inactivas) con sus precios -->
<!-- test: test/features/telas/presentation/bloc/telas_bloc_test.dart::sin idsucursal usa getTelas incluyendo inactivas -->
- **WHEN** se abre "Telas"
- **THEN** se ven todas las telas, ordenadas por nombre, cada una con sus cuatro precios

#### Scenario: Tela dada de baja
<!-- test: test/features/telas/presentation/screens/telas_screen_test.dart::las inactivas llevan el chip "Inactivo" y el nombre atenuado -->
- **WHEN** una tela tiene `activo = false`
- **THEN** su tarjeta muestra "Inactivo" y el nombre atenuado

#### Scenario: Catálogo vacío o carga fallida
<!-- test: test/features/telas/presentation/screens/telas_screen_test.dart::sin telas muestra el mensaje de lista vacía -->
<!-- test: test/features/telas/presentation/bloc/telas_bloc_test.dart::error del repositorio deja la lista vacía y deja de cargar -->
- **WHEN** no hay telas o la consulta falla
- **THEN** se ve "No hay telas registradas", sin opción de reintentar

<!-- revisar: telas_bloc.dart:57 — una carga fallida (sin conexión) se muestra igual que un catálogo vacío ("No hay telas registradas"); solo se reintenta al volver de un formulario o reabrir la pantalla. -->

---

### Requirement: Buscar telas por nombre
<!-- id: TelasScreen._buildBody -->
<!-- entities: Tela -->
<!-- enforced: TelasScreen._buildBody() -->

El campo "Buscar tela..." DEBE filtrar las tarjetas a las telas cuyo nombre contiene el texto escrito, sin distinguir mayúsculas. Si nada coincide DEBE mostrar "Sin resultados para esa búsqueda". El texto y el filtro DEBEN conservarse al volver de un formulario.

#### Scenario: Filtrar
<!-- test: test/features/telas/presentation/screens/telas_screen_test.dart::filtra por nombre sin distinguir mayúsculas -->
- **WHEN** el usuario escribe "LINO" y existe "Lino crudo"
- **THEN** se ve "Lino crudo" y no las telas que no contienen "lino"

#### Scenario: Sin coincidencias
<!-- test: test/features/telas/presentation/screens/telas_screen_test.dart::sin coincidencias avisa que no hay resultados -->
- **WHEN** ninguna tela contiene el texto buscado
- **THEN** se ve "Sin resultados para esa búsqueda"

#### Scenario: Volver de editar
<!-- test: test/features/telas/presentation/screens/telas_screen_test.dart::al volver de editar, el campo y el filtro siguen coherentes -->
- **WHEN** el usuario busca, abre una tela y vuelve
- **THEN** el campo conserva el texto y la lista sigue filtrada por él

---

### Requirement: Navegar desde el catálogo de telas
<!-- id: TelasScreen._telaCard -->
<!-- entities: Tela -->
<!-- enforced: TelasScreen.build(), TelasScreen._telaCard() -->

El botón "+" (etiqueta "Agregar tela") DEBE abrir el formulario de alta; tocar la tarjeta o su lápiz "Modificar" DEBE abrir el formulario de edición; en ambos casos, al volver, el catálogo DEBE volver a consultarse. Los botones "Colores" y "Fotos" de cada tarjeta DEBEN abrir los colores y las fotos de esa tela, sin volver a consultar el catálogo al regresar.

#### Scenario: Agregar
<!-- test: test/features/telas/presentation/screens/telas_screen_test.dart::el botón + navega a /tela/0 y recarga al volver -->
- **WHEN** el usuario toca "+" y luego vuelve
- **THEN** se abrió el alta y al volver el catálogo se recarga

#### Scenario: Modificar
<!-- test: test/features/telas/presentation/screens/telas_screen_test.dart::tocar la tarjeta también abre /tela/:id y recarga al volver -->
<!-- test: test/features/telas/presentation/screens/telas_screen_test.dart::"Modificar" navega a /tela/:id y recarga al volver -->
- **WHEN** el usuario toca la tarjeta o "Modificar" y luego vuelve
- **THEN** se abrió la edición de esa tela y al volver el catálogo se recarga

#### Scenario: Colores y fotos
<!-- test: test/features/telas/presentation/screens/telas_screen_test.dart::"Colores" navega a /tela-colores/:id sin recargar al volver -->
<!-- test: test/features/telas/presentation/screens/telas_screen_test.dart::"Fotos" navega a /tela-fotos/:id sin recargar al volver -->
- **WHEN** el usuario toca "Colores" o "Fotos" en una tarjeta
- **THEN** se abren los colores o las fotos de esa tela y al volver no se recarga el catálogo

---

### Requirement: Dar de alta una tela
<!-- id: TelaFormCubit.onSubmit -->
<!-- entities: Tela, telas -->
<!-- enforced: TelaFormCubit.onSubmit(), TelaFormCubit._toMap(), TelasBloc.createTela(), TelasDatasourceImpl.createTela() -->

El formulario de alta se titula "Crear Tela", tiene "Nombre", "Precio X Menor", "Precio X Mayor", "Precio X Rollo" y "Precio Compra" vacíos (los precios con sufijo "Bs"), no tiene el interruptor "Activo" y ofrece "Guardar". Al guardar con datos válidos DEBE insertar la tela con el nombre sin espacios alrededor, los cuatro precios como número y `activo = true`, mostrar "Realizado correctamente" y volver. Si el servidor falla DEBE mostrar "Hubo un error" y quedarse.

#### Scenario: Formulario vacío
<!-- test: test/features/telas/presentation/screens/tela_screen_test.dart::muestra "Crear Tela", el botón "Guardar" y sin switch Activo -->
<!-- test: test/features/telas/presentation/bloc/tela_form_cubit_test.dart::tela nueva deja precios vacíos y activo en true -->
- **WHEN** se abre el alta
- **THEN** se ve "Crear Tela" con todos los campos vacíos, "Guardar" y sin interruptor "Activo"

#### Scenario: Guardar una tela nueva
<!-- test: test/features/telas/presentation/screens/tela_screen_test.dart::"Guardar" envía al repo el nombre y los precios parseados -->
<!-- test: test/features/telas/presentation/bloc/tela_form_cubit_test.dart::create envía precios parseados a double -->
<!-- test: integration_test/flujos/telas.dart::crea una tela desde el formulario -->
- **WHEN** el usuario completa nombre y precios válidos y toca "Guardar"
- **THEN** queda una tela activa con esos datos, se ve "Realizado correctamente" y se vuelve al catálogo

#### Scenario: Falla al guardar
<!-- test: test/features/telas/presentation/screens/tela_screen_test.dart::un error del repo avisa y se queda en el formulario -->
<!-- test: test/features/telas/presentation/bloc/telas_bloc_test.dart::createTela con error devuelve false y no modifica la lista -->
- **WHEN** el servidor rechaza o no responde el alta
- **THEN** se ve "Hubo un error" y el formulario sigue abierto

<!-- revisar: tela_screen.dart:108-115 + material_button_widget.dart:29 — "Guardar" no se bloquea mientras se envía: dos toques rápidos insertan dos telas iguales (no hay UNIQUE en telas.nombre). -->

---

### Requirement: Validar el nombre y los precios de la tela
<!-- id: TelaFormCubit._isFormInvalid -->
<!-- entities: Tela -->
<!-- enforced: TelaFormCubit._isFormInvalid(), 20261003000100_integridad_stock_y_ventas.sql:telas_precios_no_negativos -->

"Guardar" o "Modificar" NO DEBEN enviar nada al servidor si el nombre sin espacios está vacío o si alguno de los cuatro precios está vacío, no es un número o es negativo; DEBEN mostrar "Hubo un error" y quedarse en el formulario. La base también rechaza precios negativos.

#### Scenario: Nombre vacío
<!-- test: test/features/telas/presentation/screens/tela_screen_test.dart::validaciones (no llaman al repo) -->
<!-- test: test/features/telas/presentation/bloc/tela_form_cubit_test.dart::nombre de solo espacios devuelve false -->
- **WHEN** el nombre está vacío o tiene solo espacios
- **THEN** no se guarda y se ve "Hubo un error"

#### Scenario: Precio vacío
<!-- test: test/features/telas/presentation/bloc/tela_form_cubit_test.dart::cualquier precio vacío devuelve false -->
- **WHEN** alguno de los cuatro precios está vacío
- **THEN** no se guarda y se ve "Hubo un error"

#### Scenario: Precio no numérico
<!-- test: test/features/telas/presentation/bloc/tela_form_cubit_test.dart::precio no numérico devuelve false -->
- **WHEN** un precio no se puede leer como número (por ejemplo "abc")
- **THEN** no se guarda y se ve "Hubo un error"

#### Scenario: Precio negativo
<!-- test: test/features/telas/presentation/bloc/tela_form_cubit_test.dart::precio negativo devuelve false -->
<!-- test: supabase/tests/database/05_restricciones.test.sql::telas: no acepta <columna> negativo -->
- **WHEN** un precio es menor que 0
- **THEN** la app no lo envía y la base lo rechazaría si llegara

---

### Requirement: Modificar una tela
<!-- id: TelaFormCubit.onSubmit -->
<!-- entities: Tela, telas -->
<!-- enforced: TelaFormCubit.new(), TelaFormCubit.onSubmit(), TelasBloc.updateTela(), TelasDatasourceImpl.updateTela() -->

El formulario de una tela existente se titula "Editar Tela" y precarga el nombre, los cuatro precios (también los que valen 0) y el estado "Activo"; "Modificar" DEBE guardar nombre, precios y estado, mostrar "Realizado correctamente" y volver. Un precio 0 ya guardado NO DEBE obligar a reescribirlo para poder guardar.

#### Scenario: Precarga
<!-- test: test/features/telas/presentation/screens/tela_screen_test.dart::precarga los campos con "Editar Tela" y "Modificar" -->
<!-- test: test/features/telas/presentation/bloc/tela_form_cubit_test.dart::tela existente precarga sus precios (también los 0) y su activo -->
- **WHEN** se abre una tela existente
- **THEN** se ve "Editar Tela" con sus datos, el interruptor "Activo" y el botón "Modificar"

#### Scenario: Cambiar un precio
<!-- test: test/features/telas/presentation/screens/tela_screen_test.dart::"Modificar" envía el id y los cambios al repo -->
<!-- test: integration_test/flujos/telas.dart::modifica el precio y al desactivarla deja de ofrecerse en la venta -->
- **WHEN** el usuario cambia un precio y toca "Modificar"
- **THEN** la tela queda con el precio nuevo en la base y se vuelve al catálogo

#### Scenario: Tela con un precio en 0
<!-- test: test/features/telas/presentation/screens/tela_screen_test.dart::una tela con un precio en 0 (no se vende así) se guarda sin tener que reescribirlo -->
- **WHEN** la tela tiene un precio en 0 y el usuario modifica otro campo
- **THEN** se guarda sin tocar el campo en 0

#### Scenario: Falla al modificar
<!-- test: test/features/telas/presentation/bloc/telas_bloc_test.dart::updateTela con error devuelve false y no modifica la lista -->
- **WHEN** el servidor rechaza o no responde la modificación
- **THEN** se ve "Hubo un error" y el formulario sigue abierto

---

### Requirement: Dar de baja o reactivar una tela sin borrarla
<!-- id: TelaFormCubit.onActivoChanged -->
<!-- entities: Tela, telas -->
<!-- enforced: TelaFormCubit.onActivoChanged(), TelaFormCubit.onSubmit(), TelasDatasourceImpl.updateTela(), 20261003000100_integridad_stock_y_ventas.sql:REVOKE DELETE ON telas -->

En la edición, el interruptor "Activo" (con la aclaración "Las telas inactivas no se ofrecen en las ventas") DEBE controlar `telas.activo`: apagarlo y tocar "Modificar" DEBE dar de baja la tela sin borrarla; encenderlo y tocar "Modificar" DEBE reactivarla. No existe otra forma de eliminar una tela.

#### Scenario: Dar de baja
<!-- test: test/features/telas/presentation/screens/tela_screen_test.dart::apagar el switch Activo da de baja la tela al modificar -->
- **WHEN** el usuario apaga "Activo" y toca "Modificar"
- **THEN** la tela queda con `activo = false` y sigue en el catálogo con la marca "Inactivo"

#### Scenario: Reactivar
<!-- test: test/features/telas/presentation/screens/tela_screen_test.dart::una tela inactiva precarga el switch apagado y se reactiva -->
- **WHEN** se abre una tela dada de baja, se enciende "Activo" y se toca "Modificar"
- **THEN** la tela vuelve a `activo = true`

---

### Requirement: No ofrecer en la venta una tela dada de baja
<!-- id: TelasDatasourceImpl.getTelasPorSucursal -->
<!-- entities: Tela, telas -->
<!-- enforced: TelasDatasourceImpl.getTelasPorSucursal(), TelasDatasourceImpl.getTelas() -->

El selector de telas de la venta DEBE ofrecer solo telas con `activo = true`, tanto con la disponibilidad por sucursal como con el catálogo completo de la regla de transición.

#### Scenario: Tela desactivada
<!-- test: integration_test/flujos/telas.dart::modifica el precio y al desactivarla deja de ofrecerse en la venta -->
- **WHEN** una tela se da de baja y se abre el registro de venta de telas de una sucursal
- **THEN** la tela no aparece en el selector

---

### Requirement: Avisar cuando no se puede cargar la tela a editar
<!-- id: TelaBloc._onLoadRequested -->
<!-- entities: Tela -->
<!-- enforced: TelaBloc._onLoadRequested(), TelasDatasourceImpl.getTela(), TelaScreen.build() -->

Al abrir una tela existente, la app DEBE mostrar un indicador de progreso mientras la consulta; si la consulta falla DEBE mostrar una pantalla "Tela" con "No se pudo cargar. Revisá la conexión y volvé a intentar." y botón volver. Si el id no existe, DEBE mostrar el formulario de alta vacío.

#### Scenario: Falla la carga
<!-- test: test/features/telas/presentation/screens/tela_screen_test.dart::si la carga de la tela falla, la pantalla no revienta -->
<!-- test: test/features/telas/presentation/bloc/tela_bloc_test.dart::error del repositorio deja de cargar y no deja tela -->
- **WHEN** la consulta de la tela falla
- **THEN** se ve "No se pudo cargar. Revisá la conexión y volvé a intentar." y se puede volver

#### Scenario: Id inexistente
<!-- test: test/features/telas/presentation/bloc/tela_bloc_test.dart::con id inexistente queda la tela vacía que devuelve el repositorio -->
- **WHEN** se abre el formulario de un id que no existe
- **THEN** se ve el formulario "Crear Tela" vacío

---

### Requirement: Usar precio 0 para indicar que la tela no se vende en esa modalidad
<!-- id: TelaFormCubit._isFormInvalid -->
<!-- entities: Tela, telas, catalogo_telas_web, top_telas_web -->
<!-- enforced: TelaFormCubit._isFormInvalid(), 20261003000100_integridad_stock_y_ventas.sql:telas_precios_no_negativos, 20261021000000_fotos_de_productos.sql:catalogo_telas_web, 20260925000000_prod_schema.sql:top_telas_web -->

Un precio 0 DEBE aceptarse al guardar, en la app y en la base, y significa que la tela no se vende en esa modalidad (menor, mayor o rollo). Las vistas públicas DEBEN publicar ese precio como vacío (NULL); el ranking público NO DEBE incluir telas con los tres precios de venta en 0. En la app, el precio 0 se muestra como cualquier otro valor.

#### Scenario: Guardar un precio 0
<!-- test: supabase/tests/database/05_restricciones.test.sql::telas: precio 0 está permitido (= no se vende en esa modalidad) -->
- **WHEN** se guarda una tela con "Precio X Rollo" = 0
- **THEN** la base acepta la tela con ese precio en 0

#### Scenario: Catálogo público
<!-- test: supabase/tests/database/07_vistas_web.test.sql::catalogo_telas_web: también telas sin precio, precio 0 → NULL, solo colores activos con vínculo activo (orden sin mayúsculas), fotos activas por id y foto = la primera -->
- **WHEN** la web lee el catálogo de una tela activa con un precio en 0
- **THEN** ese precio llega vacío y los demás con su valor

#### Scenario: Ranking público
<!-- test: supabase/tests/database/07_vistas_web.test.sql::top_telas_web: no publica telas sin ningún precio ni inactivas, aunque vendan más -->
- **WHEN** una tela vendida tiene los tres precios de venta en 0
- **THEN** no aparece en el ranking público

---

### Requirement: Ver los colores de una tela
<!-- id: TelasDatasourceImpl.getColoresTela -->
<!-- entities: ColorItem, colores, tela_colores -->
<!-- enforced: TelasDatasourceImpl.getColoresTela(), TelaColoresCubit.load(), TelaColoresScreen.build(), ProductoColoresList.build() -->

La pantalla de colores de una tela DEBE titularse con el nombre de la tela ("Colores de la tela" si no se conoce) y listar bajo "Colores" todos los colores activos, ordenados por nombre de la A a la Z sin distinguir mayúsculas, cada uno con su muestra redonda, su nombre y un interruptor encendido si existe un vínculo con `activo = true` en `tela_colores` para esa tela. Los colores dados de baja NO DEBEN aparecer. Mientras carga muestra un indicador de progreso; si la carga falla la lista queda vacía, sin aviso.

#### Scenario: Colores de la tela
<!-- test: test/features/telas/presentation/screens/tela_colores_screen_test.dart::el título es el nombre de la tela y hay un switch por color -->
<!-- test: test/features/telas/presentation/screens/tela_colores_screen_test.dart::cada color muestra su muestra con el hex -->
- **WHEN** se abren los colores de una tela
- **THEN** el título es el nombre de la tela y hay un interruptor por color activo, encendido en los vinculados

#### Scenario: Orden de los colores
<!-- test: test/features/telas/infrastructure/datasources/telas_datasource_impl_test.dart::colores de la tela > getColoresTela los trae por nombre, de la A a la Z sin distinguir mayúsculas -->
<!-- test: test/features/telas/infrastructure/datasources/telas_datasource_impl_test.dart::colores de la tela > la pantalla muestra los interruptores en ese orden -->
- **WHEN** se abren los colores de una tela y los colores activos son "Rojo", "azul" y "Verde"
- **THEN** se listan "azul", "Rojo" y "Verde": por nombre de la A a la Z, sin distinguir mayúsculas

#### Scenario: Nombre desconocido
<!-- test: test/features/telas/presentation/screens/tela_colores_screen_test.dart::sin nombre de tela usa el título genérico -->
- **WHEN** no se pudo obtener el nombre de la tela
- **THEN** el título es "Colores de la tela"

---

### Requirement: Vincular o desvincular un color de una tela
<!-- id: TelaColoresCubit.toggleColor -->
<!-- entities: ColorItem, tela_colores -->
<!-- enforced: TelaColoresCubit.toggleColor(), TelasDatasourceImpl.setColorTela() -->

Encender el interruptor de un color DEBE crear o actualizar (upsert por tela y color) el vínculo en `tela_colores` con `activo = true`; apagarlo DEBE dejarlo con `activo = false`, sin borrarlo. El interruptor DEBE cambiar recién cuando la base confirmó; si falla, DEBE quedar como estaba, sin mensaje.

#### Scenario: Vincular
<!-- test: test/features/telas/presentation/screens/tela_colores_screen_test.dart::encender un color lo vincula con setColorTela -->
<!-- test: integration_test/flujos/telas.dart::vincula y desvincula un color de la tela -->
- **WHEN** el usuario enciende un color
- **THEN** queda el vínculo tela-color con `activo = true`

#### Scenario: Desvincular
<!-- test: test/features/telas/presentation/screens/tela_colores_screen_test.dart::apagar un color lo desvincula (baja lógica) -->
- **WHEN** el usuario apaga un color vinculado
- **THEN** el vínculo queda con `activo = false` (la fila sigue existiendo)

#### Scenario: Falla al guardar
<!-- test: test/features/telas/presentation/screens/tela_colores_screen_test.dart::si el repo falla, el switch queda como estaba -->
- **WHEN** la escritura del vínculo falla
- **THEN** el interruptor queda como estaba y no aparece ningún mensaje

---

### Invariant: Los precios de una tela nunca son negativos
<!-- entities: telas -->
<!-- enforced: 20261003000100_integridad_stock_y_ventas.sql:telas_precios_no_negativos, TelaFormCubit._isFormInvalid() -->
<!-- verified_by: supabase/tests/database/05_restricciones.test.sql::telas: no acepta <columna> negativo -->

`precxmen`, `precxmay`, `precxrollo` y `precxcompra` DEBEN ser siempre mayores o iguales a 0.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Las telas y sus colores vinculados nunca se borran físicamente
<!-- entities: telas, tela_colores -->
<!-- enforced: 20261003000100_integridad_stock_y_ventas.sql:REVOKE DELETE ON telas, tela_colores -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::DELETE físico solo en ventas y detalle_ventas -->

Ningún usuario de la app DEBE poder borrar filas de `telas` ni de `tela_colores`: la baja es siempre `activo = false`.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Un solo vínculo por tela y color
<!-- entities: tela_colores -->
<!-- enforced: 20260925000000_prod_schema.sql:tela_colores_pkey, TelasDatasourceImpl.setColorTela() -->
<!-- verified_by: supabase/tests/database/05_restricciones.test.sql::tela_colores: un vínculo por tela+color -->

Cada par (tela, color) DEBE tener como máximo una fila en `tela_colores`.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Una tela sin precio o sin estado se trata como precio 0 y activa
<!-- entities: Tela -->
<!-- enforced: TelaMapper.jsonToEntity() -->
<!-- verified_by: test/features/telas/infrastructure/mappers/tela_mapper_test.dart::precios null o faltantes quedan en 0 -->
<!-- verified_by: test/features/telas/infrastructure/mappers/tela_mapper_test.dart::activo null o faltante queda activa -->

Al leer una tela, un precio ausente o nulo DEBE tomarse como 0, un nombre ausente como texto vacío y un `activo` ausente o nulo como activa.

> Last verified: 2026-11-06 (commit 1d15233)

<!-- uncertainty: slug, descripción, ancho y categoría de la tela (publicados por la web) no tienen campos en el formulario de la app. -->
<!-- uncertainty: los precios del catálogo no se usan en la venta de telas de esta app (la venta pertenece a ventas-telas); "precio 0 = no se vende" solo tiene efecto observable en las vistas públicas. -->

---

### Invariant: Categoría y nombre saneados por la base
<!-- id: telas.saneamiento_catalogo -->
<!-- entities: Tela, telas, categorias -->
<!-- enforced: supabase/migrations/20261110000000_saneamiento_catalogo.sql:normalizar_nombre, DEFAULT telas.categoria_id -->

Toda tela DEBE quedar con `categoria_id` = "Telas" aunque la app no lo mande (DEFAULT 1), y su `nombre` DEBE
guardarse recortado, sin espacios dobles y con mayúscula inicial, al crear y al modificar (disparador
`normalizar_nombre`). Un nombre ya limpio NO DEBE cambiar. Vale para Flutter, Android, iOS y la landing.

#### Scenario: Alta sin categoría y con espacios
<!-- test: supabase/tests/database/11_saneamiento_catalogo.test.sql::tela nueva queda en la categoría Telas -->
<!-- test: supabase/tests/database/11_saneamiento_catalogo.test.sql::nombre de tela recortado, sin dobles espacios y con mayúscula inicial -->
- **WHEN** se inserta una tela "  tull   de  prueba " sin `categoria_id`
- **THEN** queda "Tull de prueba" con `categoria_id = 1`
