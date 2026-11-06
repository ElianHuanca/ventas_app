---
description: Gestión de sucursales (listado, alta, modificación y baja lógica, con aviso si la sucursal a editar no carga) y disponibilidad de telas por sucursal (tela_sucursales): qué telas se venden en cada una, con la regla de transición de ofrecer todo el catálogo si la sucursal no tiene vínculos.
---

# Spec: sucursales

> Extraído automáticamente por spec-miner. Última extracción: 2026-11-06.
> Fuente: lib/features/sucursales/ (sucursales_datasource_impl.dart, sucursal_mapper.dart, tela_sucursal_mapper.dart, sucursales_bloc.dart, sucursal_bloc.dart, sucursal_form_cubit.dart, sucursal_disponibilidad_cubit.dart, sucursales_screen.dart, sucursal_screen.dart, sucursal_disponibilidad_screen.dart), lib/features/telas/infrastructure/datasources/telas_datasource_impl.dart (getTelasPorSucursal), lib/features/telas/presentation/bloc/telas_bloc.dart, lib/main.dart, lib/config/router/app_router.dart, lib/features/shared/ (screen1.dart, carga_fallida.dart, show_snackbar.dart, itemDashboard.dart), supabase/migrations/20260925000000_prod_schema.sql, supabase/migrations/20261003000100_integridad_stock_y_ventas.sql
> Last verified: 2026-11-06 (commit 1d15233)

---

### Requirement: Listar las sucursales activas
<!-- id: SucursalesDatasourceImpl.getSucursales -->
<!-- entities: Sucursal, sucursales -->
<!-- enforced: SucursalesDatasourceImpl.getSucursales(), SucursalesBloc._onLoadRequested(), SucursalesScreen._buildBody() -->

La app DEBE mostrar solo las sucursales con `activo = true`, ordenadas por id ascendente, como tarjetas en una grilla de dos columnas con el nombre en mayúsculas. El mismo listado, titulado "Sucursales" y con menú lateral, es el inicio de la app (venta de telas) y la pantalla de gestión del menú "Sucursales". Mientras carga DEBE mostrar un indicador de progreso a pantalla completa.

#### Scenario: Hay sucursales activas
<!-- test: test/features/sucursales/presentation/screens/sucursales_screen_test.dart::muestra una tarjeta por sucursal con el nombre en mayúsculas -->
<!-- test: test/features/sucursales/presentation/bloc/sucursales_bloc_test.dart::carga inicial trae las sucursales -->
- **WHEN** se abre el listado y la base tiene sucursales activas
- **THEN** se ve una tarjeta por sucursal, en orden de id, con el nombre en mayúsculas

#### Scenario: Sucursal dada de baja
<!-- test: integration_test/flujos/sucursales.dart::modifica el nombre y la da de baja (baja lógica) -->
- **WHEN** una sucursal tiene `activo = false`
- **THEN** no aparece en el listado

#### Scenario: Cargando
<!-- test: test/features/sucursales/presentation/screens/sucursales_screen_test.dart::mientras carga muestra el loader en vez de las tarjetas -->
- **WHEN** la consulta de sucursales todavía no respondió
- **THEN** se ve el indicador de progreso en lugar de las tarjetas

---

### Requirement: Consultar las sucursales una sola vez por ejecución de la app
<!-- id: SucursalesBloc._onLoadRequested -->
<!-- entities: Sucursal -->
<!-- enforced: SucursalesBloc.new(), SucursalesBloc._onLoadRequested(), HuantexApp.build() -->

El listado de sucursales DEBE consultarse una sola vez, la primera vez que se muestra después de abrir la app, y compartirse entre el inicio y la gestión; después solo DEBE cambiar con las altas, ediciones y bajas hechas desde la propia app. Si la consulta falla, el listado DEBE quedar vacío sin mensaje de error ni opción de reintentar.

#### Scenario: Falla la consulta
<!-- test: test/features/sucursales/presentation/bloc/sucursales_bloc_test.dart::error del repositorio deja la lista vacía -->
<!-- test: test/features/sucursales/presentation/screens/sucursales_screen_test.dart::sin sucursales solo queda la tarjeta para agregar -->
- **WHEN** la consulta de sucursales falla (por ejemplo, sin conexión)
- **THEN** el inicio queda sin tarjetas y la gestión muestra solo "Agregar Sucursal"

#### Scenario: Alta reflejada en el inicio
<!-- test: test/features/sucursales/presentation/screens/sucursales_screen_test.dart::refleja una sucursal creada en el bloc global -->
- **WHEN** se crea una sucursal desde la gestión
- **THEN** aparece también en el inicio sin volver a consultar la base

<!-- revisar: sucursales_bloc.dart:46 + main.dart:35-41 — el listado es global y nadie vuelve a pedir SucursalesLoadRequested: si la primera carga falla, queda vacío hasta reiniciar la app, y los cambios hechos desde otro dispositivo no se ven. -->

---

### Requirement: Elegir una sucursal en el inicio para ver sus ventas de telas
<!-- id: SucursalesScreen._buildBody -->
<!-- entities: Sucursal -->
<!-- enforced: SucursalesScreen._buildBody() -->

En el inicio, tocar una sucursal DEBE abrir las ventas de telas de esa sucursal. El inicio es pantalla raíz: tiene menú lateral, no tiene botón volver y NO DEBE ofrecer la tarjeta para agregar sucursales.

#### Scenario: Tocar una sucursal en el inicio
<!-- test: test/features/sucursales/presentation/screens/sucursales_screen_test.dart::tocar una sucursal navega a sus ventas -->
- **WHEN** el usuario toca una sucursal en el inicio
- **THEN** se abren las ventas de telas de esa sucursal

#### Scenario: Sin alta en el inicio
<!-- test: test/features/sucursales/presentation/screens/sucursales_screen_test.dart::no ofrece la tarjeta para agregar sucursal -->
<!-- test: test/features/sucursales/presentation/screens/sucursales_screen_test.dart::es pantalla raíz: tiene menú lateral y no botón volver -->
- **WHEN** se muestra el inicio
- **THEN** no hay tarjeta "Agregar Sucursal", hay menú lateral y no hay botón volver

---

### Requirement: Abrir el formulario de una sucursal desde la gestión
<!-- id: SucursalesScreen._buildBody -->
<!-- entities: Sucursal -->
<!-- enforced: SucursalesScreen._buildBody() -->

En la gestión de sucursales, al final de la grilla DEBE haber una tarjeta "Agregar Sucursal" que abre el formulario vacío; tocar una sucursal DEBE abrir su formulario de edición.

#### Scenario: Agregar
<!-- test: test/features/sucursales/presentation/screens/sucursales_screen_test.dart::muestra las sucursales y la tarjeta para agregar -->
<!-- test: test/features/sucursales/presentation/screens/sucursales_screen_test.dart::la tarjeta para agregar navega al formulario con id 0 -->
- **WHEN** el usuario toca "Agregar Sucursal"
- **THEN** se abre el formulario de alta

#### Scenario: Editar
<!-- test: test/features/sucursales/presentation/screens/sucursales_screen_test.dart::tocar una sucursal navega a su formulario -->
- **WHEN** el usuario toca una sucursal en la gestión
- **THEN** se abre el formulario de edición de esa sucursal

---

### Requirement: Dar de alta una sucursal
<!-- id: SucursalFormCubit.onSubmit -->
<!-- entities: Sucursal, sucursales -->
<!-- enforced: SucursalFormCubit.onSubmit(), SucursalesBloc.createSucursal(), SucursalesDatasourceImpl.createSucursal() -->

El formulario de alta se titula "Crear Sucursal", tiene el campo "Nombre" vacío y el botón "Guardar", sin "Eliminar" ni "Disponibilidad de telas". Al guardar con un nombre válido DEBE insertar una sucursal con el nombre sin espacios alrededor (las demás columnas quedan con su valor por defecto: activa y sin slug, dirección ni coordenadas), agregarla al final del listado, mostrar "Realizado correctamente" y volver al listado. Si el servidor falla DEBE mostrar "Hubo un error" y quedarse en el formulario.

#### Scenario: Formulario vacío
<!-- test: test/features/sucursales/presentation/screens/sucursal_screen_test.dart::muestra el formulario vacío con "Crear Sucursal" y "Guardar" -->
<!-- test: test/features/sucursales/presentation/screens/sucursal_screen_test.dart::no ofrece Eliminar ni la disponibilidad de telas -->
- **WHEN** se abre el alta
- **THEN** se ve "Crear Sucursal" con el nombre vacío y solo el botón "Guardar"

#### Scenario: Guardar una sucursal nueva
<!-- test: test/features/sucursales/presentation/screens/sucursal_screen_test.dart::Guardar crea la sucursal, la agrega al listado y vuelve -->
<!-- test: test/features/sucursales/presentation/bloc/sucursal_form_cubit_test.dart::el nombre se guarda con trim -->
<!-- test: integration_test/flujos/sucursales.dart::crea una sucursal desde el formulario -->
- **WHEN** el usuario escribe " Centro " y toca "Guardar"
- **THEN** queda una sucursal activa "Centro" en la base, aparece al final del listado, se ve "Realizado correctamente" y se vuelve al listado

#### Scenario: Falla al guardar
<!-- test: test/features/sucursales/presentation/screens/sucursal_screen_test.dart::si el repositorio falla avisa y se queda en el formulario -->
- **WHEN** el servidor rechaza o no responde el alta
- **THEN** se ve "Hubo un error" y el formulario sigue abierto con lo escrito

<!-- revisar: sucursal_screen.dart:69-73 + material_button_widget.dart:29 — "Guardar" no se bloquea mientras se envía: dos toques rápidos insertan dos sucursales iguales (no hay UNIQUE en sucursales.nombre). -->

---

### Requirement: Exigir nombre a la sucursal
<!-- id: SucursalFormCubit.onSubmit -->
<!-- entities: Sucursal -->
<!-- enforced: SucursalFormCubit.onSubmit(), 20260925000000_prod_schema.sql:sucursales.nombre NOT NULL -->

Guardar o modificar con el nombre vacío o de solo espacios NO DEBE enviar nada al servidor; DEBE mostrar "Hubo un error" y quedarse en el formulario.

#### Scenario: Nombre vacío al crear
<!-- test: test/features/sucursales/presentation/screens/sucursal_screen_test.dart::con el nombre vacío no envía y muestra el error -->
<!-- test: test/features/sucursales/presentation/bloc/sucursal_form_cubit_test.dart::nombre de solo espacios devuelve false sin llamar callbacks -->
- **WHEN** el nombre está vacío o tiene solo espacios y se toca "Guardar"
- **THEN** no se crea nada y se ve "Hubo un error"

#### Scenario: Borrar el nombre al editar
<!-- test: test/features/sucursales/presentation/screens/sucursal_screen_test.dart::borrar el nombre y Modificar no envía -->
- **WHEN** en la edición se borra el nombre y se toca "Modificar"
- **THEN** la sucursal no cambia y se ve "Hubo un error"

---

### Requirement: Modificar el nombre de una sucursal
<!-- id: SucursalFormCubit.onSubmit -->
<!-- entities: Sucursal, sucursales -->
<!-- enforced: SucursalFormCubit.onSubmit(), SucursalesBloc.updateSucursal(), SucursalesDatasourceImpl.updateSucursal() -->

El formulario de una sucursal existente se titula "Editar Sucursal", precarga el nombre y ofrece "Modificar", "Eliminar" y "Disponibilidad de telas". "Modificar" DEBE guardar el nombre sin espacios alrededor, reemplazarlo en el listado, mostrar "Realizado correctamente" y volver. Volver sin tocar "Modificar" NO DEBE guardar cambios.

#### Scenario: Precarga
<!-- test: test/features/sucursales/presentation/screens/sucursal_screen_test.dart::precarga la sucursal con "Editar Sucursal" y "Modificar" -->
- **WHEN** se abre una sucursal existente
- **THEN** se ve "Editar Sucursal" con su nombre y los botones "Modificar", "Eliminar" y "Disponibilidad de telas"

#### Scenario: Renombrar
<!-- test: test/features/sucursales/presentation/screens/sucursal_screen_test.dart::Modificar actualiza la sucursal en el listado y vuelve -->
<!-- test: integration_test/flujos/sucursales.dart::modifica el nombre y la da de baja (baja lógica) -->
- **WHEN** el usuario cambia el nombre y toca "Modificar"
- **THEN** el nombre cambia en la base y en el listado, se ve "Realizado correctamente" y se vuelve

#### Scenario: Volver sin guardar
<!-- test: test/features/sucursales/presentation/screens/sucursal_screen_test.dart::el botón volver regresa al listado sin guardar -->
- **WHEN** el usuario edita el nombre y toca volver
- **THEN** se vuelve al listado y la sucursal no cambia

---

### Requirement: Dar de baja una sucursal sin borrarla
<!-- id: SucursalFormCubit.onDelete -->
<!-- entities: Sucursal, sucursales -->
<!-- enforced: SucursalFormCubit.onDelete(), SucursalesBloc.deleteSucursal(), SucursalesDatasourceImpl.deleteSucursal(), 20261003000100_integridad_stock_y_ventas.sql:REVOKE DELETE ON sucursales -->

"Eliminar" DEBE marcar la sucursal con `activo = false`, sin borrar la fila y sin pedir confirmación. Si la base confirma que actualizó la fila, la sucursal DEBE salir del listado, verse "Realizado correctamente" y volver; si no actualizó ninguna fila o falló, DEBE verse "Hubo un error" y la sucursal DEBE seguir en el listado.

#### Scenario: Baja confirmada
<!-- test: test/features/sucursales/presentation/screens/sucursal_screen_test.dart::Eliminar da de baja la sucursal, la quita y vuelve -->
<!-- test: integration_test/flujos/sucursales.dart::modifica el nombre y la da de baja (baja lógica) -->
- **WHEN** el usuario toca "Eliminar" en una sucursal existente
- **THEN** la fila queda con `activo = false`, la sucursal sale del listado y se vuelve

#### Scenario: Baja no confirmada
<!-- test: test/features/sucursales/presentation/screens/sucursal_screen_test.dart::si la baja no se confirma avisa y conserva la sucursal -->
<!-- test: test/features/sucursales/presentation/bloc/sucursales_bloc_test.dart::deleteSucursal con respuesta false no modifica la lista -->
- **WHEN** la base no devuelve la fila actualizada o la operación falla
- **THEN** se ve "Hubo un error" y la sucursal sigue en el listado

<!-- revisar: sucursal_screen.dart:79-88 — "Eliminar" da de baja sin diálogo de confirmación (Fotos sí confirma antes de quitar). -->

---

### Requirement: Avisar cuando no se puede cargar la sucursal a editar
<!-- id: SucursalBloc._onLoadRequested -->
<!-- entities: Sucursal -->
<!-- enforced: SucursalBloc._onLoadRequested(), SucursalesDatasourceImpl.getSucursal(), SucursalScreen.build() -->

Al abrir el formulario de una sucursal existente, la app DEBE mostrar un indicador de progreso mientras la consulta; si la consulta falla DEBE mostrar una pantalla "Sucursal" con "No se pudo cargar. Revisá la conexión y volvé a intentar." y botón volver. Si el id no existe en la base, DEBE mostrar el formulario de alta vacío.

#### Scenario: Cargando
<!-- test: test/features/sucursales/presentation/screens/sucursal_screen_test.dart::mientras carga la sucursal muestra el loader -->
- **WHEN** la sucursal todavía no llegó
- **THEN** se ve el indicador de progreso

#### Scenario: Falla la carga
<!-- test: test/features/sucursales/presentation/screens/sucursal_screen_test.dart::si falla la carga de la sucursal la pantalla no se rompe -->
<!-- test: test/features/sucursales/presentation/bloc/sucursal_bloc_test.dart::error del repositorio termina la carga sin sucursal -->
- **WHEN** la consulta de la sucursal falla
- **THEN** se ve "No se pudo cargar. Revisá la conexión y volvé a intentar." y se puede volver

#### Scenario: Id inexistente
<!-- test: test/features/sucursales/presentation/bloc/sucursal_bloc_test.dart::id inexistente queda con la sucursal vacía que devuelve el repo -->
- **WHEN** se abre el formulario de un id que no existe
- **THEN** se ve el formulario "Crear Sucursal" vacío

---

### Requirement: Abrir la disponibilidad de telas de una sucursal
<!-- id: SucursalScreen._sucursalInformation -->
<!-- entities: Sucursal -->
<!-- enforced: SucursalScreen._sucursalInformation() -->

En la edición de una sucursal, el botón "Disponibilidad de telas" DEBE abrir la pantalla de disponibilidad de esa sucursal. El alta no lo ofrece.

#### Scenario: Ir a la disponibilidad
<!-- test: test/features/sucursales/presentation/screens/sucursal_screen_test.dart::"Disponibilidad de telas" navega a la de esa sucursal -->
- **WHEN** el usuario toca "Disponibilidad de telas" en una sucursal existente
- **THEN** se abre la disponibilidad de telas de esa sucursal

---

### Requirement: Ver qué telas se venden en una sucursal
<!-- id: SucursalesDatasourceImpl.getTelasSucursal -->
<!-- entities: TelaSucursal, telas, tela_sucursales -->
<!-- enforced: SucursalesDatasourceImpl.getTelasSucursal(), TelaSucursalMapper.jsonToEntity(), SucursalDisponibilidadCubit.load(), SucursalDisponibilidadScreen.build() -->

La pantalla "Disponibilidad de telas" DEBE mostrar la ayuda "Activá qué telas se pueden vender en esta sucursal. Si no activás ninguna, la venta muestra todo el catálogo." y un interruptor por tela, en el orden por nombre que devuelve la base. El interruptor DEBE estar encendido solo si la tela tiene un vínculo con `activo = true` para esa sucursal en `tela_sucursales` (un vínculo apagado o con `activo` nulo cuenta como no disponible). Lista todas las telas, también las dadas de baja. Mientras carga muestra un indicador de progreso; si la carga falla queda solo la ayuda, sin aviso.

#### Scenario: Telas con y sin vínculo
<!-- test: test/features/sucursales/presentation/screens/sucursal_disponibilidad_screen_test.dart::muestra el título, la ayuda y un switch por tela -->
<!-- test: test/features/sucursales/presentation/screens/sucursal_disponibilidad_screen_test.dart::cada switch refleja la disponibilidad de la tela -->
<!-- test: test/features/sucursales/presentation/bloc/sucursal_disponibilidad_cubit_test.dart::carga las telas con su disponibilidad en la sucursal -->
<!-- test: test/features/sucursales/infrastructure/mappers/sucursales_mappers_test.dart::disponible true cuando hay un vínculo activo -->
<!-- test: test/features/sucursales/infrastructure/mappers/sucursales_mappers_test.dart::un vínculo con activo null no cuenta como disponible -->
- **WHEN** se abre la disponibilidad de una sucursal
- **THEN** cada tela aparece con su interruptor encendido si tiene vínculo activo con la sucursal y apagado si no

#### Scenario: Sin telas
<!-- test: test/features/sucursales/presentation/screens/sucursal_disponibilidad_screen_test.dart::sin telas solo muestra la ayuda -->
- **WHEN** no hay telas en el catálogo o la carga falló
- **THEN** solo se ve el texto de ayuda

#### Scenario: Cargando
<!-- test: test/features/sucursales/presentation/screens/sucursal_disponibilidad_screen_test.dart::mientras carga muestra el loader -->
- **WHEN** la consulta todavía no respondió
- **THEN** se ve el indicador de progreso

<!-- revisar: sucursales_datasource_impl.dart:56-60 — la consulta no filtra telas.activo: la disponibilidad lista también telas dadas de baja, que igual nunca se ofrecen en la venta. -->

---

### Requirement: Habilitar o quitar una tela en una sucursal
<!-- id: SucursalDisponibilidadCubit.toggleTela -->
<!-- entities: TelaSucursal, tela_sucursales -->
<!-- enforced: SucursalDisponibilidadCubit.toggleTela(), SucursalesDatasourceImpl.setTelaSucursal() -->

Encender el interruptor de una tela DEBE crear o actualizar (upsert por tela y sucursal) el vínculo en `tela_sucursales` con `activo = true`; apagarlo DEBE dejar el vínculo con `activo = false`, sin borrarlo. El interruptor DEBE cambiar recién cuando la base confirmó; si la escritura falla, DEBE quedar como estaba, sin mensaje. Las demás telas no cambian.

#### Scenario: Habilitar una tela
<!-- test: test/features/sucursales/presentation/screens/sucursal_disponibilidad_screen_test.dart::activar una tela la vincula a la sucursal -->
<!-- test: test/features/sucursales/presentation/bloc/sucursal_disponibilidad_cubit_test.dart::marca disponible solo la tela indicada -->
<!-- test: integration_test/flujos/sucursales.dart::la disponibilidad de telas limita lo que ofrece la venta de la sucursal -->
- **WHEN** el usuario enciende el interruptor de una tela
- **THEN** en la base queda el vínculo de esa tela con la sucursal con `activo = true` y solo ese interruptor cambia

#### Scenario: Quitar una tela
<!-- test: test/features/sucursales/presentation/screens/sucursal_disponibilidad_screen_test.dart::desactivar una tela la desvincula de la sucursal -->
<!-- test: test/features/sucursales/presentation/bloc/sucursal_disponibilidad_cubit_test.dart::desmarca una tela disponible -->
- **WHEN** el usuario apaga el interruptor de una tela habilitada
- **THEN** el vínculo queda con `activo = false` (la fila sigue existiendo)

#### Scenario: Falla al guardar
<!-- test: test/features/sucursales/presentation/screens/sucursal_disponibilidad_screen_test.dart::si el repositorio falla el switch queda como estaba -->
- **WHEN** la escritura del vínculo falla
- **THEN** el interruptor vuelve a mostrar el estado anterior y no aparece ningún mensaje

---

### Requirement: Ofrecer en la venta de telas solo las telas habilitadas en la sucursal
<!-- id: TelasDatasourceImpl.getTelasPorSucursal -->
<!-- entities: Tela, tela_sucursales, telas -->
<!-- enforced: TelasDatasourceImpl.getTelasPorSucursal(), TelasBloc._onLoadRequested() -->

El selector de telas del registro de venta de una sucursal DEBE ofrecer solo las telas activas que tienen un vínculo activo con esa sucursal, ordenadas por nombre sin distinguir mayúsculas. Regla de transición: si la sucursal no tiene ningún vínculo activo (nunca se configuró o se apagaron todos), DEBE ofrecer todo el catálogo de telas activas.

#### Scenario: Sucursal con telas habilitadas
<!-- test: integration_test/flujos/sucursales.dart::la disponibilidad de telas limita lo que ofrece la venta de la sucursal -->
<!-- test: test/features/telas/presentation/bloc/telas_bloc_test.dart::con idsucursal usa getTelasPorSucursal -->
- **WHEN** la sucursal tiene al menos un vínculo activo y se abre el registro de venta de telas
- **THEN** el selector ofrece solo las telas activas vinculadas y no las demás

#### Scenario: Sucursal sin ningún vínculo activo
<!-- test: integration_test/flujos/sucursales.dart::quitar una tela de la sucursal la saca de la venta; sin ninguna activa vuelve a ofrecer todo el catálogo -->
- **WHEN** la sucursal no tiene vínculos o todos están con `activo = false`
- **THEN** el selector ofrece todas las telas activas del catálogo

#### Scenario: Tela quitada de la sucursal
<!-- test: integration_test/flujos/sucursales.dart::quitar una tela de la sucursal la saca de la venta; sin ninguna activa vuelve a ofrecer todo el catálogo -->
- **WHEN** se apaga una tela y la sucursal conserva otras habilitadas
- **THEN** esa tela deja de ofrecerse y las otras siguen

#### Scenario: Vínculos activos solo con telas dadas de baja
- **WHEN** la sucursal tiene vínculos activos pero todas esas telas tienen `activo = false`
- **THEN** el selector queda vacío (no se aplica la regla de transición)

<!-- revisar: telas_datasource_impl.dart:26-39 — la regla de transición mira solo tela_sucursales.activo, no telas.activo: una sucursal cuyas telas habilitadas fueron todas dadas de baja no ofrece ninguna tela en la venta. -->

---

### Invariant: Las sucursales y su disponibilidad de telas nunca se borran físicamente
<!-- entities: sucursales, tela_sucursales -->
<!-- enforced: 20261003000100_integridad_stock_y_ventas.sql:REVOKE DELETE ON sucursales, tela_sucursales -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::DELETE físico solo en ventas y detalle_ventas -->

Ningún usuario de la app (anónimo ni logueado) DEBE poder borrar filas de `sucursales` ni de `tela_sucursales`: la baja es siempre `activo = false`.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Un solo vínculo por tela y sucursal
<!-- entities: tela_sucursales -->
<!-- enforced: 20260925000000_prod_schema.sql:tela_sucursales_pkey, SucursalesDatasourceImpl.setTelaSucursal() -->
<!-- verified_by: supabase/tests/database/05_restricciones.test.sql::tela_sucursales: un vínculo por tela+sucursal -->

Cada par (tela, sucursal) DEBE tener como máximo una fila en `tela_sucursales`; habilitar o quitar la misma tela actualiza esa fila en lugar de crear otra.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Una sucursal dada de baja no se publica en la web
<!-- entities: sucursales, sucursales_web -->
<!-- enforced: 20260925000000_prod_schema.sql:sucursales_web -->
<!-- verified_by: supabase/tests/database/07_vistas_web.test.sql::sucursales_web: no publica una sucursal dada de baja (activo = false) -->

La vista pública de sucursales DEBE incluir solo las sucursales con `activo = true`, ordenadas por id.

> Last verified: 2026-11-06 (commit 1d15233)

<!-- uncertainty: la app solo edita el nombre de la sucursal; slug, dirección, latitud y longitud (publicadas por la web) no tienen pantalla y una sucursal dada de baja no se puede reactivar desde la app. -->
<!-- uncertainty: la pantalla de ventas de telas a la que lleva el inicio y el selector del registro de venta pertenecen a la capacidad ventas-telas; aquí solo se describe qué telas ofrece según la disponibilidad. -->
