---
description: Fabricación de apliques por sucursal. Cubre elegir la sucursal, la lista de producciones por día, el registro de lo fabricado (listado de aplique+color+cantidad en memoria con fecha elegible, solo colores vinculados), el envío en una sola transacción con clave de idempotencia que acumula en la producción del día y suma al stock (creando o reactivando la fila de inventario), y el detalle de la producción.
---

# Spec: fabricacion

> Extraído automáticamente por spec-miner. Última extracción: 2026-11-06.
> Fuentes: lib/features/apliques/presentation/screens/{fabricacion_sucursales,producciones,produccion,produccion_detalle}_screen.dart, lib/features/apliques/presentation/bloc/{produccion_form_cubit,producciones_bloc,detalle_produccion_cubit}.dart, lib/features/apliques/presentation/widgets/data_table_produccion.dart, lib/features/apliques/infrastructure/datasources/apliques_datasource_impl.dart, lib/features/apliques/infrastructure/mappers/produccion_mapper.dart, supabase/migrations/20261003000100_integridad_stock_y_ventas.sql, supabase/migrations/20261020000000_idempotencia_y_venta_telas.sql
> Last verified: 2026-11-06 (commit 1d15233)

---

### Requirement: Elegir la sucursal donde se fabrica
<!-- id: FabricacionSucursalesScreen._buildBody -->
<!-- entities: Sucursal -->
<!-- enforced: FabricacionSucursalesScreen._buildBody(), SucursalesDatasourceImpl.getSucursales() -->

La pantalla "Fabricación" (menú lateral) DEBE mostrar una tarjeta por sucursal activa, ordenadas por id y con el nombre en mayúsculas, sin botón "+" ni botón atrás; tocar una DEBE abrir sus producciones. Mientras cargan DEBE mostrar el indicador a pantalla completa; sin sucursales no hay tarjetas.

#### Scenario: Elegir una sucursal
<!-- test: test/features/apliques/presentation/screens/fabricacion_sucursales_screen_test.dart::FabricacionSucursalesScreen > tocar una sucursal navega a /fabricacion/:idsucursal -->
- **WHEN** el usuario toca una sucursal
- **THEN** se abren las producciones de esa sucursal

---

### Requirement: Listar las producciones de la sucursal por día
<!-- id: ApliquesDatasourceImpl.getProducciones -->
<!-- entities: ProduccionCabecera, Sucursal -->
<!-- enforced: ApliquesDatasourceImpl.getProducciones(), ProduccionesBloc._onLoadRequested(), ProduccionesScreen._buildBody() -->

La lista ("Fabricación") DEBE mostrar las 10 producciones más recientes de la sucursal (orden por `fecha` descendente), una tarjeta por día con la fecha d-m-aaaa, y un botón "+" ("Registrar producción"). El "+" DEBE abrir el registro y tocar una tarjeta su detalle; al volver de cualquiera DEBE recargar la lista. Mientras carga muestra el indicador a pantalla completa; si la carga falla la lista queda vacía sin aviso.

#### Scenario: Producciones por día
<!-- test: test/features/apliques/presentation/screens/producciones_screen_test.dart::muestra una card por fecha y el botón + en el AppBar -->
- **WHEN** la sucursal tiene producciones
- **THEN** se ve una tarjeta por día y el botón "+"

#### Scenario: Registrar y volver
<!-- test: test/features/apliques/presentation/screens/producciones_screen_test.dart::el botón + navega al registro y recarga al volver -->
- **WHEN** el usuario toca "+", registra y vuelve
- **THEN** la lista se recarga

<!-- revisar: un error de carga se ve igual que "sin producciones" (producciones_bloc.dart:47 descarta la excepción) -->

---

### Requirement: Ofrecer apliques activos y solo sus colores vinculados
<!-- id: ProduccionFormCubit.onApliqueChanged -->
<!-- entities: Aplique, ColorItem, ApliqueColor, StockAplique -->
<!-- enforced: ProduccionFormCubit.load(), ProduccionFormCubit.onApliqueChanged(), ApliquesDatasourceImpl.getColoresAplique(), _ProduccionScreenState._widget() -->

El registro DEBE cargar los apliques activos (orden por nombre sin distinguir mayúsculas) y el stock de la sucursal. Al elegir un aplique DEBE ofrecer en el selector de color solo los colores activos con vínculo activo con ese aplique (tengan o no inventario en la sucursal), cada uno con su muestra y "Color (stock: N)" (0 si no hay fila de inventario); el selector está deshabilitado hasta elegir aplique y cambiar de aplique reinicia el color. Con un color elegido DEBE mostrar "Stock actual en esta sucursal: N uds". Mientras carga DEBE mostrar un indicador en lugar del formulario; si la carga de colores falla el selector queda vacío.

#### Scenario: Solo colores vinculados
<!-- test: test/features/apliques/presentation/bloc/produccion_form_cubit_test.dart::onApliqueChanged > carga solo los colores vinculados al aplique -->
- **WHEN** se elige un aplique con colores vinculados y no vinculados
- **THEN** el selector ofrece solo los vinculados

#### Scenario: Stock actual
<!-- test: test/features/apliques/presentation/screens/produccion_screen_test.dart::al elegir el color muestra el stock actual de la sucursal -->
- **WHEN** se elige un color
- **THEN** se ve "Stock actual en esta sucursal: N uds"

#### Scenario: Cambiar de aplique
<!-- test: test/features/apliques/presentation/screens/produccion_screen_test.dart::al cambiar de aplique el color se reinicia (idcolor 0 y hint) -->
- **WHEN** se elige otro aplique
- **THEN** el color elegido se borra

---

### Requirement: Elegir la fecha de la producción
<!-- id: ProduccionFormCubit.onFechaChanged -->
<!-- entities: ProduccionCabecera -->
<!-- enforced: _ProduccionScreenState._selectFecha(), ProduccionFormCubit.onFechaChanged() -->

El registro DEBE proponer el día de hoy, mostrarlo como dd/mm/aaaa y permitir elegir otro día en un calendario (2020–2100); cancelar el calendario NO cambia la fecha. La producción DEBE registrarse en el día elegido.

#### Scenario: Fecha anterior
<!-- test: integration_test/flujos/fabricacion.dart::con fecha anterior registra la producción de ese día, sin las líneas quitadas -->
- **WHEN** se elige un día anterior y se guarda
- **THEN** la producción queda en ese día

---

### Requirement: Agregar una línea al listado de fabricación
<!-- id: ProduccionFormCubit.addDetalleProduccion -->
<!-- entities: Produccion, Aplique, ColorItem -->
<!-- enforced: _ProduccionScreenState._widget(), ProduccionFormCubit.addDetalleProduccion() -->

"Añadir" DEBE validar y mostrar "Seleccione un aplique", "Seleccione un color" o "Ingrese una cantidad válida mayor a 0" (texto, NaN, Infinity, 0 o negativa). Si pasa, DEBE agregar al principio del listado (en memoria) una línea con aplique, color (con muestra) y cantidad en unidades, y vaciar la cantidad. Si ya hay una línea del mismo aplique+color DEBE sumarle la cantidad (sin ruido de coma flotante a 6 decimales) en vez de duplicarla. NO hay control de stock al fabricar.

#### Scenario: Agregar
<!-- test: test/features/apliques/presentation/bloc/produccion_form_cubit_test.dart::addDetalleProduccion > añade la línea con nombres y limpia la cantidad -->
- **WHEN** hay aplique, color y cantidad válidos
- **THEN** el listado suma la línea y la cantidad queda vacía

#### Scenario: Mismo aplique y color
<!-- test: test/features/apliques/presentation/bloc/produccion_form_cubit_test.dart::addDetalleProduccion > mismo aplique+color suma la cantidad en vez de duplicar -->
<!-- test: test/vectores/carritos_vectores_test.dart::fabricación: el mismo aplique y color suma sin ruido (1,03 + 1 + 1,23 = 3,26); lo nuevo va primero -->
- **WHEN** se agrega dos veces el mismo aplique+color
- **THEN** queda una línea con la cantidad sumada

#### Scenario: Sin selección
<!-- test: test/features/apliques/presentation/screens/produccion_screen_test.dart::Añadir sin selección muestra error y no agrega línea -->
<!-- test: test/vectores/carritos_vectores_test.dart::fabricación: sin aplique, sin color o con una cantidad que no es mayor a 0 no agrega -->
- **WHEN** se toca "Añadir" sin aplique
- **THEN** se avisa "Seleccione un aplique" y no se agrega nada

---

### Requirement: Quitar una línea del listado de fabricación
<!-- id: ProduccionFormCubit.removeDetalleProduccion -->
<!-- entities: Produccion -->
<!-- enforced: DataTableProduccion, ProduccionFormCubit.removeDetalleProduccion() -->

"Quitar línea" DEBE sacar, sin confirmación, la primera línea que coincida en aplique, color y cantidad; sin coincidencia no cambia nada. Una línea quitada NO DEBE registrarse.

#### Scenario: Quitar
<!-- test: test/features/apliques/presentation/bloc/produccion_form_cubit_test.dart::removeDetalleProduccion > quita la línea del listado -->
- **WHEN** se quita una línea
- **THEN** sale del listado y no se registra al guardar

---

### Requirement: Registrar la producción del listado
<!-- id: ProduccionFormCubit.onFormSubmit -->
<!-- entities: Produccion, ProduccionCabecera, Inventario -->
<!-- depends_on: Agregar una línea al listado de fabricación -->
<!-- triggers: Acumular en la producción del día y sumar al stock -->
<!-- enforced: _ProduccionScreenState._widget(), ProduccionFormCubit.onFormSubmit(), ApliquesDatasourceImpl.createProduccion() -->

"Guardar" con el listado vacío DEBE avisar "Añada al menos una línea al listado" sin enviar. Si hay líneas DEBE enviar todas en una sola llamada (`registrar_produccion`) con la sucursal, el día elegido (aaaa-mm-dd), las líneas (aplique, color, cantidad) y la clave de operación. Si sale bien DEBE vaciar el listado, refrescar el stock mostrado y avisar "Producción registrada, stock actualizado", quedándose en la pantalla (con la misma fecha) para cargar otra; si el refresco del stock falla, igual se considera registrado y el listado queda vacío. Si el envío falla DEBE mostrar el texto del error (sin el prefijo "Exception: ") y conservar el listado para reintentar.

#### Scenario: Registro exitoso
<!-- test: test/features/apliques/presentation/bloc/produccion_form_cubit_test.dart::onFormSubmit > envía todas las líneas con la fecha, limpia el listado y refresca stock -->
- **WHEN** se guarda un listado con líneas y la base responde bien
- **THEN** se vacía el listado, se refresca el stock y se avisa "Producción registrada, stock actualizado"

#### Scenario: Falla el refresco del stock
<!-- test: red/fabricacion_test.dart::se corta la señal justo después del registro (falla el refresco del stock): la producción no se registra dos veces -->
- **WHEN** el registro sale bien pero el refresco del stock falla
- **THEN** el listado queda vacío y no se vuelve a registrar lo mismo

#### Scenario: Falla el registro
<!-- test: test/features/apliques/presentation/screens/produccion_screen_test.dart::si falla el registro muestra el error y conserva las líneas para reintentar -->
- **WHEN** el envío falla
- **THEN** se muestra el error y las líneas siguen para reintentar

---

### Requirement: Ignorar el doble toque en Guardar de la fabricación
<!-- id: ProduccionFormState.isSubmitting -->
<!-- entities: Produccion -->
<!-- enforced: _ProduccionScreenState._widget(), ProduccionFormCubit.onFormSubmit() -->

Mientras un registro está en curso, otro "Guardar" NO DEBE volver a registrar el listado (la pantalla ignora el toque y el envío concurrente devuelve "Ya se está registrando la producción").

#### Scenario: Doble toque
<!-- test: test/features/apliques/presentation/bloc/produccion_form_cubit_test.dart::onFormSubmit > mientras registra marca isSubmitting y un segundo envío no vuelve a registrar el lote -->
- **WHEN** se toca "Guardar" dos veces antes de que responda la base
- **THEN** el listado se registra una sola vez

---

### Requirement: Reusar la clave de operación al reintentar la fabricación
<!-- id: ProduccionFormCubit._clave -->
<!-- entities: Produccion -->
<!-- enforced: ProduccionFormCubit.onFormSubmit(), ClaveDeOperacion.para(), ClaveDeOperacion.descartar() -->

La clave DEBE quedar atada a las líneas (aplique, color, cantidad) y al día elegido. Reintentar el mismo listado DEBE llevar la misma clave; cambiar el listado o el día DEBE generar otra; otra hora del mismo día no la cambia. Después de un registro exitoso la clave DEBE descartarse.

#### Scenario: Respuesta perdida y reintento
<!-- test: red/fabricacion_test.dart::respuesta perdida y el usuario vuelve a tocar Guardar: el stock sube una sola vez y la línea queda con la cantidad una vez -->
- **WHEN** la base registró la producción, la respuesta se perdió y el usuario vuelve a guardar
- **THEN** el stock sube una sola vez

#### Scenario: Otro día
<!-- test: test/features/apliques/presentation/bloc/produccion_form_cubit_test.dart::clave de operación > otro día es otro envío; otra hora del mismo día, no -->
- **WHEN** tras una falla se cambia el día
- **THEN** lleva otra clave; otra hora del mismo día conserva la clave

---

### Requirement: Acumular en la producción del día y sumar al stock
<!-- id: 20261020000000_idempotencia_y_venta_telas.sql:registrar_produccion -->
<!-- entities: ProduccionCabecera, Produccion, Inventario -->
<!-- enforced: 20261020000000_idempotencia_y_venta_telas.sql:registrar_produccion -->

En una sola transacción la base DEBE crear la producción (cabecera) de la sucursal en esa fecha o reusar la existente; acumular cada línea por (producción, aplique, color) sumando la cantidad (también las repetidas en un mismo envío); sumar la cantidad al stock de la fila de inventario de esa sucursal, aplique y color, creándola con ese stock si no existe o reactivándola (`activo = true`) si estaba dada de baja; y devolver el id de la producción. Otra fecha u otra sucursal es otra producción; el stock es de cada sucursal y sigue sumando entre días.

#### Scenario: Primera producción
<!-- test: supabase/tests/database/03_registrar_produccion.test.sql::crea la fila de inventario que no existía, con el stock fabricado -->
- **WHEN** se fabrica un aplique+color sin fila de inventario en la sucursal
- **THEN** se crea la producción del día, la línea y la fila de inventario con ese stock

#### Scenario: Acumular en el día
<!-- test: integration_test/flujos/fabricacion.dart::registrar desde la UI sube el stock y se acumula en la producción del día -->
- **WHEN** se vuelve a fabricar el mismo aplique+color el mismo día
- **THEN** hay una sola producción y una sola línea con la cantidad sumada, y el stock sube

#### Scenario: Reactivar inventario
<!-- test: supabase/tests/database/03_registrar_produccion.test.sql::reactiva la fila de inventario dada de baja y le suma lo fabricado -->
- **WHEN** la fila de inventario estaba dada de baja
- **THEN** queda activa con lo fabricado sumado

#### Scenario: Fabricar y vender a la vez
<!-- test: concurrencia/fabricacion_test.dart::fabricar y vender el mismo aplique+color a la vez: el stock final es lo que había + lo fabricado - lo vendido -->
- **WHEN** se fabrica y se vende el mismo aplique+color al mismo tiempo
- **THEN** el stock final es lo que había + lo fabricado − lo vendido

---

### Requirement: Rechazar fabricaciones inválidas
<!-- id: 20261020000000_idempotencia_y_venta_telas.sql:registrar_produccion#validaciones -->
<!-- entities: Produccion, ProduccionCabecera -->
<!-- enforced: 20260925000000_prod_schema.sql:detalle_produccion_cantidad_check, 20260925000000_prod_schema.sql:detalle_produccion_idaplique_fkey -->

La base DEBE rechazar el envío entero, sin dejar cabecera, líneas ni stock (tampoco de las líneas válidas que venían antes), si una cantidad es 0 o negativa (aunque caiga sobre una línea existente) o el aplique o el color no existen.

#### Scenario: Cantidad 0
<!-- test: supabase/tests/database/03_registrar_produccion.test.sql::la fabricación rechazada no deja la cabecera del día -->
- **WHEN** una línea trae cantidad 0
- **THEN** se rechaza y no queda la cabecera del día

#### Scenario: Aplique inexistente
<!-- test: supabase/tests/database/03_registrar_produccion.test.sql::rechaza un aplique que no existe -->
- **WHEN** una línea trae un aplique que no existe
- **THEN** se rechaza el envío entero

<!-- revisar: 20261020000000_idempotencia_y_venta_telas.sql:213 registrar_produccion no valida p_lineas: con [] o NULL crea una producción del día vacía (todo() en 03_registrar_produccion.test.sql) -->
<!-- revisar: registrar_produccion no exige el vínculo aplique_colores (solo lo filtra la app): una app vieja puede fabricar un color no vinculado, a diferencia de crear_venta_apliques -->

---

### Requirement: Ver el detalle de una producción
<!-- id: ProduccionDetalleScreen.build -->
<!-- entities: Produccion, ProduccionCabecera -->
<!-- enforced: ProduccionDetalleScreen.build(), DetalleProduccionCubit.load(), ApliquesDatasourceImpl.getDetalleProduccion() -->

El detalle DEBE mostrar las líneas de la producción de la más nueva a la más vieja (por id), cada una con la muestra del color, "Aplique (Color)", el nombre de la sucursal y "N uds". El título DEBE ser la fecha de la producción (d-m-aaaa), o "Detalle" si no hay líneas o la fecha no se puede leer. Mientras carga DEBE mostrar un indicador; sin líneas DEBE mostrar "Todavía no hay producciones registradas".

#### Scenario: Líneas
<!-- test: test/features/apliques/presentation/screens/produccion_detalle_screen_test.dart::muestra cada línea como "Aplique (Color)" con "N uds" -->
- **WHEN** se abre una producción con líneas
- **THEN** se ve cada línea como "Aplique (Color)" con "N uds" y la fecha como título

#### Scenario: Sin líneas
<!-- test: test/features/apliques/presentation/screens/produccion_detalle_screen_test.dart::sin líneas muestra el estado vacío y el título "Detalle" -->
- **WHEN** la producción no tiene líneas (o falló la carga)
- **THEN** se ve "Todavía no hay producciones registradas" con título "Detalle"

---

### Invariant: Una sola producción por sucursal y fecha
<!-- entities: ProduccionCabecera, Sucursal -->
<!-- enforced: 20261003000100_integridad_stock_y_ventas.sql:producciones_sucursal_fecha_key -->
<!-- verified_by: supabase/tests/database/05_restricciones.test.sql::producciones: una sola producción por sucursal y fecha -->

`producciones` NO DEBE tener dos filas de la misma sucursal y fecha. `producciones.fecha` es de tipo `date` (no texto ISO como en las ventas).

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Una línea por producción, aplique y color
<!-- entities: Produccion -->
<!-- enforced: 20261003000100_integridad_stock_y_ventas.sql:detalle_produccion_linea_key -->
<!-- verified_by: supabase/tests/database/05_restricciones.test.sql::detalle_produccion: una línea por producción+aplique+color -->

`detalle_produccion` NO DEBE tener dos líneas de la misma producción, aplique y color.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Cantidad fabricada positiva
<!-- entities: Produccion -->
<!-- enforced: ProduccionFormCubit.addDetalleProduccion(), 20260925000000_prod_schema.sql:detalle_produccion_cantidad_check -->
<!-- verified_by: supabase/tests/database/05_restricciones.test.sql::detalle_produccion: no acepta cantidad 0 -->

Toda línea de producción DEBE tener cantidad > 0.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Lo fabricado suma exacto al stock
<!-- entities: Inventario, Produccion -->
<!-- enforced: 20261020000000_idempotencia_y_venta_telas.sql:registrar_produccion -->
<!-- verified_by: concurrencia/fabricacion_test.dart::mismo aplique+color+sucursal+día desde $cantidadDispositivos dispositivos a la vez: una cabecera, una línea y el stock exacto -->

El stock de un aplique+color en una sucursal DEBE subir exactamente lo fabricado, también con varios dispositivos registrando a la vez y con reintentos de la misma clave.

> Last verified: 2026-11-06 (commit 1d15233)

<!-- uncertainty: CLAUDE.md dice que Fabricación registra cada aplique+color "al toque (sin carrito)"; el código arma un listado en memoria (Añadir) y lo registra entero con Guardar en una sola llamada. La spec describe el código -->
<!-- uncertainty: el texto de error que se muestra es el toString() de la excepción (p. ej. de PostgrestException); no hay mensajes amigables por causa -->
<!-- deferred: lib/features/apliques/domain/entities/produccion.dart, lib/features/apliques/domain/entities/produccion_cabecera.dart, lib/features/apliques/infrastructure/repositories/apliques_repository_impl.dart -->
