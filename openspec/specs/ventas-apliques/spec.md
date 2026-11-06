---
description: Venta de apliques por sucursal con stock por color. Cubre elegir la sucursal, la lista de ventas por día, el registro con carrito en memoria (solo apliques activos y colores vinculados con inventario activo, bloqueo de sobre-stock, cálculo de totales y ganancias, descuento), el envío en una sola transacción con clave de idempotencia que acumula en la venta del día y descuenta el stock, y el detalle de la venta.
---

# Spec: ventas-apliques

> Extraído automáticamente por spec-miner. Última extracción: 2026-11-06.
> Fuentes: lib/features/apliques/presentation/screens/{venta_apliques_sucursales,ventas_apliques,venta_apliques,venta_apliques_detalle}_screen.dart, lib/features/apliques/presentation/bloc/{venta_apliques_form_cubit,ventas_apliques_bloc,detalle_venta_apliques_cubit,apliques_bloc}.dart, lib/features/apliques/presentation/widgets/data_table_apliques.dart, lib/features/apliques/infrastructure/datasources/{ventas_apliques_datasource_impl,apliques_datasource_impl}.dart, supabase/migrations/20261004000100_venta_apliques_por_dia.sql, supabase/migrations/20261007000000_venta_apliques_colores_vinculados.sql, supabase/migrations/20261020000000_idempotencia_y_venta_telas.sql
> Last verified: 2026-11-06 (commit 1d15233)

---

### Requirement: Elegir la sucursal para vender apliques
<!-- id: VentaApliquesSucursalesScreen._buildBody -->
<!-- entities: Sucursal -->
<!-- enforced: VentaApliquesSucursalesScreen._buildBody(), SucursalesDatasourceImpl.getSucursales() -->

La pantalla "Venta Apliques" (menú lateral) DEBE mostrar una tarjeta por sucursal activa, ordenadas por id y con el nombre en mayúsculas, sin botón "+" ni botón atrás; tocar una DEBE abrir las ventas de apliques de esa sucursal. Mientras cargan DEBE mostrar el indicador a pantalla completa; sin sucursales no hay tarjetas.

#### Scenario: Elegir una sucursal
<!-- test: test/features/apliques/presentation/screens/venta_apliques_sucursales_screen_test.dart::VentaApliquesSucursalesScreen > tocar una sucursal navega a /venta-apliques/:idsucursal -->
- **WHEN** el usuario toca una sucursal
- **THEN** se abren las ventas de apliques de esa sucursal

---

### Requirement: Listar las ventas de apliques de la sucursal por día
<!-- id: VentasApliquesDatasourceImpl.getVentasApliques -->
<!-- entities: VentaAplique, Sucursal -->
<!-- enforced: VentasApliquesDatasourceImpl.getVentasApliques(), VentasApliquesBloc._onLoadRequested(), VentasApliquesScreen._buildBody() -->

La lista ("Venta de Apliques") DEBE mostrar las 10 ventas de apliques más recientes de la sucursal (orden por `fecha` descendente), una tarjeta por venta del día con la fecha d-m-aaaa, y un botón "+" ("Registrar venta"). El "+" DEBE abrir el registro y tocar una tarjeta DEBE abrir su detalle pasando la fecha; al volver de cualquiera DEBE recargar la lista. Si la carga falla la lista queda vacía sin aviso.

#### Scenario: Ventas del día
<!-- test: test/features/apliques/presentation/screens/ventas_apliques_screen_test.dart::muestra una tarjeta por fecha, el título y el botón + -->
- **WHEN** la sucursal tiene ventas de apliques
- **THEN** se ve una tarjeta por día, de la más reciente a la más vieja

#### Scenario: Abrir el detalle
<!-- test: test/features/apliques/presentation/screens/ventas_apliques_screen_test.dart::tap en una fecha navega al detalle con idventa y fecha ISO, y recarga al volver -->
- **WHEN** el usuario toca la tarjeta de un día
- **THEN** se abre el detalle de esa venta con su fecha y al volver la lista se recarga

#### Scenario: Sin ventas
<!-- test: test/features/apliques/presentation/screens/ventas_apliques_screen_test.dart::sin ventas no muestra tarjetas pero sí el botón + -->
- **WHEN** la sucursal no tiene ventas de apliques
- **THEN** no hay tarjetas pero sigue el botón "+"

<!-- revisar: un error de carga se ve igual que "sin ventas" (ventas_apliques_bloc.dart:49 descarta la excepción) -->

---

### Requirement: Ofrecer solo colores vinculados con inventario activo en la sucursal
<!-- id: ApliquesDatasourceImpl.getStock -->
<!-- entities: Aplique, Inventario, ApliqueColor, StockAplique -->
<!-- enforced: ApliquesBloc._onLoadRequested(), ApliquesDatasourceImpl.getStock(), ApliquesDatasourceImpl.soloColoresVinculados(), _VentaApliquesScreenState._widget() -->

El registro DEBE ofrecer en "Seleccione un Aplique" los apliques activos (orden por nombre sin distinguir mayúsculas). El selector de color DEBE estar deshabilitado hasta elegir un aplique y ofrecer solo los colores del aplique elegido que tienen fila de inventario activa en la sucursal y vínculo activo en `aplique_colores` (aunque su stock sea 0), en orden alfabético sin distinguir mayúsculas, cada uno con su muestra y el texto "Color (stock: N)". Cambiar de aplique DEBE reiniciar el color elegido y su stock. Mientras cargan apliques y stock DEBE mostrar un indicador en lugar de los selectores.

#### Scenario: Colores del aplique en la sucursal
<!-- test: test/features/apliques/presentation/screens/venta_apliques_screen_test.dart::selección de aplique y color > ofrece solo los colores con stock del aplique elegido -->
- **WHEN** se elige un aplique
- **THEN** el selector de color ofrece solo los colores de ese aplique con inventario en la sucursal, con su stock

#### Scenario: Cambiar de aplique
<!-- test: test/features/apliques/presentation/screens/venta_apliques_screen_test.dart::selección de aplique y color > al cambiar de aplique se reinicia el color elegido -->
- **WHEN** se elige otro aplique
- **THEN** el color elegido se borra

#### Scenario: Color desvinculado con stock
<!-- test: test/features/apliques/infrastructure/datasources/stock_colores_vinculados_test.dart::sin vínculos no ofrece nada, aunque haya stock -->
- **WHEN** un color tiene stock pero su vínculo con el aplique está inactivo
- **THEN** no se ofrece

<!-- revisar: apliques_datasource_impl.dart:47-52 no filtra colores.activo: un color dado de baja con vínculo e inventario activos se sigue ofreciendo y la base lo vende (inventario_con_ventas sí lo excluye) -->

---

### Requirement: Agregar una línea al carrito de apliques
<!-- id: VentaApliquesFormCubit.addDetalle -->
<!-- entities: DetalleVentaAplique, Aplique, StockAplique -->
<!-- enforced: _VentaApliquesScreenState._widget(), VentaApliquesFormCubit.addDetalle() -->

"Añadir" DEBE validar en este orden y mostrar el primer error: "Seleccione un aplique", "Seleccione un color", "Ingrese una cantidad válida", "Ingrese un precio válido" (texto, NaN o Infinity), "La cantidad debe ser mayor a 0", "El precio debe ser mayor a 0". Si pasa, DEBE agregar al principio del carrito (en memoria) una línea "Aplique (Color)" con cantidad en unidades, precio, total y ganancias, y vaciar Cantidad y Precio; con error los campos NO se vacían. La tabla muestra Nombre, Cantidad, "PBs", "TBs" y la fila Total del carrito.

#### Scenario: Línea válida
<!-- test: test/features/apliques/presentation/screens/venta_apliques_screen_test.dart::líneas > Añadir agrega la línea a la tabla, suma el total y limpia cantidad y precio -->
- **WHEN** hay aplique y color elegidos, cantidad 2 y precio 25 con stock suficiente
- **THEN** el carrito suma la línea "Aplique (Color)" de 50 Bs y los campos quedan vacíos

#### Scenario: Sin aplique
<!-- test: test/features/apliques/presentation/screens/venta_apliques_screen_test.dart::líneas > Añadir sin aplique avisa y no agrega nada -->
- **WHEN** se toca "Añadir" sin aplique
- **THEN** se avisa "Seleccione un aplique" y el carrito no cambia

---

### Requirement: Bloquear el sobre-stock en el carrito de apliques
<!-- id: VentaApliquesFormCubit.addDetalle#stock -->
<!-- entities: StockAplique, DetalleVentaAplique -->
<!-- enforced: VentaApliquesFormCubit.addDetalle(), venta_apliques_form_cubit._sinRuido() -->

"Añadir" DEBE rechazar con "Stock insuficiente. Disponible: N" una cantidad que, sumada a lo que el carrito ya tiene de ese mismo aplique+color (a cualquier precio, sin ruido de coma flotante a 6 decimales), supere el stock del color elegido. Lo de otro color no cuenta.

#### Scenario: Supera el stock
<!-- test: test/features/apliques/presentation/screens/venta_apliques_screen_test.dart::líneas > sobre-stock muestra "Stock insuficiente..." y no agrega la línea -->
- **WHEN** se pide más que el stock disponible
- **THEN** se avisa "Stock insuficiente. Disponible: N" y no se agrega

#### Scenario: Cuenta lo del carrito
<!-- test: test/features/apliques/presentation/screens/venta_apliques_screen_test.dart::líneas > el sobre-stock cuenta lo que ya está en la venta -->
- **WHEN** el carrito ya tiene 8 de un color con stock 10 y se piden 3 más
- **THEN** se rechaza

#### Scenario: Decimales al límite
<!-- test: test/features/apliques/presentation/bloc/venta_apliques_form_cubit_test.dart::bloqueo de sobre-stock > sumar cantidades con decimales no rechaza la última unidad -->
- **WHEN** con stock 2.07 se agregan 1.07 y luego 1
- **THEN** se acepta (no se rechaza por ruido de coma flotante)

---

### Requirement: Acumular en el carrito las líneas del mismo aplique, color y precio
<!-- id: VentaApliquesFormCubit.addDetalle#mismo-precio -->
<!-- entities: DetalleVentaAplique -->
<!-- enforced: VentaApliquesFormCubit.addDetalle() -->

Si el carrito ya tiene una línea del mismo aplique, color y precio, "Añadir" DEBE sumarle la cantidad y recalcular su total y ganancias con la cantidad acumulada; a otro precio DEBE ser otra línea.

#### Scenario: Mismo precio
<!-- test: test/features/apliques/presentation/bloc/venta_apliques_form_cubit_test.dart::addDetalle válido > merge por aplique+color+precio suma cantidad -->
- **WHEN** se agrega dos veces el mismo aplique y color al mismo precio
- **THEN** queda una línea con la cantidad sumada

#### Scenario: Otro precio
<!-- test: test/features/apliques/presentation/bloc/venta_apliques_form_cubit_test.dart::addDetalle válido > mismo aplique+color con distinto precio son líneas separadas -->
- **WHEN** se agrega el mismo aplique y color a otro precio
- **THEN** queda otra línea

---

### Requirement: Calcular el total y las ganancias de la venta de apliques
<!-- id: venta_apliques_form_cubit._centavos -->
<!-- entities: DetalleVentaAplique, Aplique -->
<!-- enforced: venta_apliques_form_cubit._centavos(), VentaApliquesFormCubit.addDetalle(), _VentaApliquesScreenState._widget() -->

El total de una línea DEBE ser cantidad × precio redondeado a centavos con la mitad hacia arriba, tras quitar el ruido a 6 decimales. Las ganancias DEBEN ser (precio − costo de fabricación del aplique) × cantidad redondeado igual, también cuando el costo es 0 (pueden ser negativas). El total y las ganancias del carrito DEBEN cambiar exactamente lo que cambia cada línea. "Total a pagar" DEBE mostrar total del carrito − descuento redondeado a centavos (un descuento no numérico cuenta como 0).

#### Scenario: Mitad del centavo
<!-- test: test/features/apliques/presentation/bloc/venta_apliques_form_cubit_test.dart::addDetalle válido > la mitad del centavo redondea hacia arriba, como numeric -->
- **WHEN** se agregan 1.5 unidades a 0.15 Bs
- **THEN** el total de la línea es 0.23 Bs

#### Scenario: Ganancia por costo
<!-- test: test/features/apliques/presentation/bloc/venta_apliques_form_cubit_test.dart::addDetalle válido > agrega línea con nombre compuesto, total y ganancia por costo -->
- **WHEN** el aplique cuesta 10 de fabricar y se venden 2 a 25
- **THEN** la línea tiene total 50 y ganancias 30

#### Scenario: Total a pagar
<!-- test: test/features/apliques/presentation/screens/venta_apliques_screen_test.dart::líneas > el descuento se resta del total a pagar -->
- **WHEN** el carrito suma 100 y el descuento es 15
- **THEN** "Total a pagar" muestra 85.0 Bs

---

### Requirement: Quitar una línea del carrito de apliques
<!-- id: VentaApliquesFormCubit.removeDetalle -->
<!-- entities: DetalleVentaAplique -->
<!-- enforced: DataTableApliques, VentaApliquesFormCubit.removeDetalle() -->

"Quitar línea" DEBE sacar, sin confirmación, la primera línea que coincida en aplique, color, cantidad y precio, y restar su total y ganancias. Una línea quitada NO DEBE venderse ni descontar stock al guardar.

#### Scenario: Línea quitada
<!-- test: integration_test/flujos/venta_apliques.dart::una línea quitada del carrito no se vende ni descuenta su stock, y el descuento queda en la venta -->
- **WHEN** se quita una línea y se confirma la venta
- **THEN** esa línea no queda en la base ni descuenta stock

---

### Requirement: Confirmar y registrar la venta de apliques
<!-- id: VentaApliquesFormCubit.onFormSubmit -->
<!-- entities: VentaAplique, DetalleVentaAplique -->
<!-- depends_on: Agregar una línea al carrito de apliques -->
<!-- triggers: Acumular en la venta de apliques del día y descontar el stock -->
<!-- enforced: _VentaApliquesScreenState._widget(), dialogoDeAlerta(), VentaApliquesFormCubit.onFormSubmit(), VentasApliquesDatasourceImpl.createVentaAplique() -->

"Guardar" con el carrito vacío DEBE avisar "Agregue al menos un aplique a la venta" sin pedir confirmación. Si hay líneas DEBE pedir confirmación ("Confirmar Venta" / "¿Está seguro de registrar esta venta de apliques?", "Cancelar" / "Confirmar"); cancelar NO envía y conserva el carrito. Al confirmar DEBE enviar en una sola llamada (`crear_venta_apliques`) la sucursal, la fecha y hora actuales (ISO 8601), el total neto (total del carrito − descuento), las ganancias del carrito (sin restar el descuento), el descuento (vacío = 0), las líneas y la clave de operación. NO DEBE enviar si el descuento no es un número finito o supera el total. Con éxito avisa "Realizado correctamente" y vuelve a la lista; con error avisa "Hubo un error", se queda y conserva el carrito.

#### Scenario: Venta confirmada
<!-- test: test/features/apliques/presentation/screens/venta_apliques_screen_test.dart::guardar > confirmar envía totales y líneas al repo, avisa y vuelve al historial -->
- **WHEN** se confirma una venta con líneas
- **THEN** se registra, se avisa "Realizado correctamente" y se vuelve a la lista

#### Scenario: Descuento mayor al total
<!-- test: test/features/apliques/presentation/screens/venta_apliques_screen_test.dart::guardar > un descuento mayor al total no envía la venta -->
- **WHEN** el descuento supera el total del carrito
- **THEN** no se envía nada y se avisa "Hubo un error"

#### Scenario: Falla el envío
<!-- test: test/features/apliques/presentation/screens/venta_apliques_screen_test.dart::guardar > si el repo falla avisa el error y se queda en la pantalla -->
- **WHEN** la base rechaza la venta o no hay conexión
- **THEN** se avisa "Hubo un error" y el carrito sigue para reintentar

<!-- revisar: venta_apliques_form_cubit.dart:200,209 guarda en ventas_apliques.total el neto (líneas − descuento), mientras registrar_venta_telas guarda en ventas.total el bruto (suma de líneas): el mismo campo significa cosas distintas en telas y apliques (lo suman igual las RPC del dashboard) -->

---

### Requirement: Ignorar el doble toque en Guardar de la venta de apliques
<!-- id: VentaApliquesFormCubit.enviando -->
<!-- entities: VentaAplique -->
<!-- enforced: _VentaApliquesScreenState._widget(), VentaApliquesFormCubit.onFormSubmit() -->

Mientras un envío está en curso, otro "Guardar" NO DEBE abrir otra confirmación ni volver a enviar la venta.

#### Scenario: Doble toque
<!-- test: test/features/apliques/presentation/bloc/venta_apliques_form_cubit_test.dart::onFormSubmit > un segundo envío mientras se guarda no registra la venta dos veces -->
- **WHEN** se confirma dos veces antes de que responda la base
- **THEN** la venta se envía una sola vez

---

### Requirement: Reusar la clave de operación al reintentar la venta de apliques
<!-- id: VentaApliquesFormCubit._clave -->
<!-- entities: VentaAplique -->
<!-- enforced: VentaApliquesFormCubit.onFormSubmit(), ClaveDeOperacion.para(), ClaveDeOperacion.descartar() -->

La clave DEBE quedar atada a las líneas y al descuento (no incluye el día). Reintentar el mismo carrito DEBE llevar la misma clave; agregar, quitar o cambiar una línea o el descuento DEBE generar otra; agregar y quitar la misma línea conserva la clave. Después de una venta exitosa la clave DEBE descartarse.

#### Scenario: Respuesta perdida y reintento
<!-- test: red/venta_apliques_test.dart::respuesta perdida y el usuario vuelve a tocar Guardar: el stock se descuenta una sola vez y la venta del día suma una sola vez -->
- **WHEN** la base aplicó la venta, la respuesta se perdió y el usuario vuelve a confirmar
- **THEN** el stock se descuenta y la venta del día suma una sola vez

#### Scenario: Cambia el carrito tras la falla
<!-- test: test/features/apliques/presentation/bloc/venta_apliques_form_cubit_test.dart::clave de operación > si después de la falla cambia el carrito, es otro envío: otra clave -->
- **WHEN** tras un envío fallido se cambia el carrito y se guarda
- **THEN** lleva otra clave

---

### Requirement: Acumular en la venta de apliques del día y descontar el stock
<!-- id: 20261020000000_idempotencia_y_venta_telas.sql:crear_venta_apliques -->
<!-- entities: VentaAplique, DetalleVentaAplique, Inventario -->
<!-- enforced: 20261020000000_idempotencia_y_venta_telas.sql:crear_venta_apliques, 20261004000100_venta_apliques_por_dia.sql:ventas_apliques_sucursal_dia_key -->

En una sola transacción la base DEBE crear la venta de apliques del día de la sucursal (día = primeros 10 caracteres de `fecha`) o reusar la existente sin tocar su `fecha`, sumándole el total, las ganancias y el descuento recibidos; acumular cada línea por (venta, aplique, color, precio) sumando cantidad, total y ganancias; descontar la cantidad del stock de la fila de inventario activa de esa sucursal, aplique y color; y devolver el id de la venta. Dos ventas simultáneas del mismo aplique+color se serializan.

#### Scenario: Venta del día
<!-- test: supabase/tests/database/02_crear_venta_apliques.test.sql::sigue habiendo una sola venta ese día: suma total, ganancias y descuento y conserva la fecha del primer registro -->
- **WHEN** se registra una segunda venta el mismo día
- **THEN** se suma a la venta del día, que conserva la fecha del primer registro

#### Scenario: Descuento de stock
<!-- test: integration_test/flujos/venta_apliques.dart::registra la venta del día y descuenta el stock -->
- **WHEN** se venden 3 unidades de un color con stock 10
- **THEN** el stock queda en 7

#### Scenario: Última unidad desde varios dispositivos
<!-- test: concurrencia/venta_apliques_test.dart::última unidad: de $cantidadDispositivos dispositivos vendiendo 1 a la vez solo venden los que tienen stock y el stock queda en 0 -->
- **WHEN** varios dispositivos venden a la vez más unidades de las que hay
- **THEN** solo se venden las que había y el stock queda en 0

---

### Requirement: Rechazar la venta entera si una línea no tiene stock
<!-- id: 20261020000000_idempotencia_y_venta_telas.sql:crear_venta_apliques#stock -->
<!-- entities: Inventario, DetalleVentaAplique -->
<!-- enforced: 20261020000000_idempotencia_y_venta_telas.sql:crear_venta_apliques, 20261003000100_integridad_stock_y_ventas.sql:inventario_stock_no_negativo -->

La base DEBE rechazar la venta entera, sin dejar cabecera, líneas ni movimientos de stock, con "Stock insuficiente: <nombre>" (HINT `stock_insuficiente`) si para alguna línea no hay fila de inventario activa en esa sucursal con stock >= la cantidad: stock insuficiente (también sumando líneas del mismo aplique+color), fila dada de baja aunque tenga stock, aplique+color sin inventario en la sucursal, o stock de otra sucursal.

#### Scenario: Sin stock suficiente
<!-- test: supabase/tests/database/02_crear_venta_apliques.test.sql::la venta fallida no deja líneas ni descuenta el stock de la línea que sí tenía -->
- **WHEN** una línea pide más que el stock y otra sí tiene stock
- **THEN** no se guarda nada y ningún stock se mueve

#### Scenario: Inventario dado de baja
<!-- test: supabase/tests/database/02_crear_venta_apliques.test.sql::falla si la fila de inventario está dada de baja (aunque tenga stock) -->
- **WHEN** la fila de inventario está inactiva aunque tenga stock
- **THEN** se rechaza con HINT stock_insuficiente

#### Scenario: Stock de otra sucursal
<!-- test: supabase/tests/database/02_crear_venta_apliques.test.sql::el stock de una sucursal no sirve para vender en otra -->
- **WHEN** solo otra sucursal tiene stock de ese aplique+color
- **THEN** se rechaza

---

### Requirement: Rechazar la venta entera si el color no está vinculado al aplique
<!-- id: 20261020000000_idempotencia_y_venta_telas.sql:crear_venta_apliques#color_no_vinculado -->
<!-- entities: ApliqueColor, DetalleVentaAplique -->
<!-- enforced: 20261020000000_idempotencia_y_venta_telas.sql:crear_venta_apliques -->

La base DEBE rechazar la venta entera con "Color no habilitado para el aplique: <nombre>" (HINT `color_no_vinculado`) si alguna línea trae un color sin vínculo activo con su aplique (deshabilitado o nunca vinculado), aunque haya stock; el stock de ese color no se toca.

#### Scenario: Color deshabilitado
<!-- test: supabase/tests/database/02_crear_venta_apliques.test.sql::falla si el color está deshabilitado en aplique_colores aunque haya stock -->
- **WHEN** una línea trae un color con el vínculo inactivo
- **THEN** se rechaza la venta entera con HINT color_no_vinculado

#### Scenario: Color nunca vinculado
<!-- test: supabase/tests/database/02_crear_venta_apliques.test.sql::falla si el color nunca se vinculó al aplique -->
- **WHEN** una línea trae un color que nunca se vinculó al aplique
- **THEN** se rechaza la venta entera

---

### Requirement: Rechazar ventas de apliques sin líneas o con cantidades inválidas
<!-- id: 20261020000000_idempotencia_y_venta_telas.sql:crear_venta_apliques#validaciones -->
<!-- entities: VentaAplique, DetalleVentaAplique -->
<!-- enforced: 20261020000000_idempotencia_y_venta_telas.sql:crear_venta_apliques, 20261003000100_integridad_stock_y_ventas.sql:detalle_ventas_apliques_montos_check, 20261003000100_integridad_stock_y_ventas.sql:ventas_apliques_montos_check -->

La base DEBE rechazar con "La venta no tiene líneas" un `p_detalles` vacío o que no es un arreglo (antes de mirar la clave), y DEBE rechazar la venta entera si una cantidad es 0 o negativa (aunque caiga sobre una línea existente), un precio o total de línea es negativo, o el total o el descuento de la venta quedarían negativos.

#### Scenario: Sin líneas
<!-- test: supabase/tests/database/02_crear_venta_apliques.test.sql::rechaza una venta sin líneas -->
- **WHEN** llega un arreglo de líneas vacío
- **THEN** se rechaza con "La venta no tiene líneas"

#### Scenario: Cantidad negativa sobre una línea existente
<!-- test: supabase/tests/database/02_crear_venta_apliques.test.sql::rechaza una cantidad negativa aunque caiga sobre una línea existente -->
- **WHEN** una línea con cantidad negativa coincide con una línea ya guardada
- **THEN** se rechaza la venta entera

<!-- revisar: 20261020000000_idempotencia_y_venta_telas.sql:97 con p_detalles NULL el IF no corta: crea o suma total/ganancias/descuento a la venta del día sin líneas ni stock (todo() en 02_crear_venta_apliques.test.sql) -->

---

### Requirement: Ver el detalle de una venta de apliques
<!-- id: VentaApliquesDetalleScreen.build -->
<!-- entities: DetalleVentaAplique, VentaAplique -->
<!-- enforced: VentaApliquesDetalleScreen.build(), DetalleVentaApliquesCubit.load(), VentasApliquesDatasourceImpl.getDetalleVentasApliques() -->

El detalle DEBE titularse con la fecha recibida (d-m-aaaa) o "Detalle" si no la hay, y mostrar cada línea con su nombre, "X uds x Y Bs" y su total, más una fila "Total" con la suma de los totales de las líneas. El descuento de la venta NO se muestra y no se pueden borrar líneas. Mientras carga DEBE mostrar un indicador; sin líneas DEBE mostrar "Venta sin líneas" y ningún total.

#### Scenario: Líneas y total
<!-- test: test/features/apliques/presentation/screens/venta_apliques_detalle_screen_test.dart::muestra el total de la venta sumando las líneas -->
- **WHEN** se abre una venta con líneas
- **THEN** se ve cada línea y el Total igual a la suma de las líneas

#### Scenario: Sin líneas
<!-- test: test/features/apliques/presentation/screens/venta_apliques_detalle_screen_test.dart::venta sin líneas muestra el estado vacío y ningún total -->
- **WHEN** la venta no tiene líneas
- **THEN** se ve "Venta sin líneas"

<!-- revisar: si la carga falla se muestra "Venta sin líneas" en vez de un error (detalle_venta_apliques_cubit.dart:43 descarta la excepción) -->

---

### Requirement: Ordenar el detalle por aplique y por unidades
<!-- id: detalle_venta_apliques_cubit._porApliqueYCantidad -->
<!-- entities: DetalleVentaAplique -->
<!-- enforced: detalle_venta_apliques_cubit._porApliqueYCantidad(), detalle_venta_apliques_cubit._aplique() -->

Las líneas del detalle DEBEN ordenarse por el nombre del aplique (lo anterior al último " (" cuando el nombre termina en ")") de la A a la Z sin distinguir mayúsculas; dentro de cada aplique, de la línea con más unidades a la de menos; a igual cantidad, por nombre completo y luego por id. Una línea vieja sin color entre paréntesis se ordena por su nombre entero.

#### Scenario: Orden por aplique y unidades
<!-- test: test/features/apliques/presentation/bloc/detalle_venta_apliques_cubit_test.dart::ordena por aplique y, dentro de cada uno, de más a menos unidades -->
- **WHEN** la venta tiene "Luna (Rojo)" 1 ud, "Flor (Azul)" 2 uds y "Flor (Rojo)" 5 uds
- **THEN** el orden es Flor (Rojo), Flor (Azul), Luna (Rojo)

---

### Invariant: Una sola venta de apliques por sucursal y día
<!-- entities: VentaAplique, Sucursal -->
<!-- enforced: 20261004000100_venta_apliques_por_dia.sql:ventas_apliques_sucursal_dia_key -->
<!-- verified_by: supabase/tests/database/05_restricciones.test.sql::ventas_apliques: una sola venta de apliques por sucursal y día (aunque cambie la hora) -->

`ventas_apliques` NO DEBE tener dos filas con la misma sucursal y el mismo día (primeros 10 caracteres de `fecha`).

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Una línea por venta, aplique, color y precio
<!-- entities: DetalleVentaAplique -->
<!-- enforced: 20261004000100_venta_apliques_por_dia.sql:detalle_ventas_apliques_linea_key -->
<!-- verified_by: supabase/tests/database/05_restricciones.test.sql::detalle_ventas_apliques: una línea por venta+aplique+color+precio -->

`detalle_ventas_apliques` NO DEBE tener dos líneas con la misma venta, aplique, color y precio.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: La venta nunca deja stock negativo
<!-- entities: Inventario -->
<!-- enforced: VentaApliquesFormCubit.addDetalle(), 20261020000000_idempotencia_y_venta_telas.sql:crear_venta_apliques, 20261003000100_integridad_stock_y_ventas.sql:inventario_stock_no_negativo -->
<!-- verified_by: supabase/tests/database/05_restricciones.test.sql::inventario: descontar por debajo de 0 falla -->

El stock de cada fila de inventario DEBE ser siempre >= 0, también con varios dispositivos vendiendo a la vez.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Las ventas de apliques no se borran
<!-- entities: VentaAplique, DetalleVentaAplique -->
<!-- enforced: 20261003000100_integridad_stock_y_ventas.sql:REVOKE DELETE -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::DELETE físico solo en ventas y detalle_ventas -->

Ningún usuario de la API DEBE poder borrar ventas de apliques ni sus líneas; la app no ofrece borrarlas.

> Last verified: 2026-11-06 (commit 1d15233)

<!-- uncertainty: el total, las ganancias y el descuento de la venta del día los manda el cliente (p_total, p_ganancias) y la base no los recalcula desde las líneas, a diferencia de registrar_venta_telas -->
<!-- uncertainty: la fecha de la venta es DateTime.now() del dispositivo al enviar (hora local sin zona); no hay selector de fecha -->
<!-- deferred: lib/features/apliques/infrastructure/mappers/venta_aplique_mapper.dart, lib/features/apliques/infrastructure/mappers/stock_aplique_mapper.dart, lib/features/apliques/infrastructure/repositories/ventas_apliques_repository_impl.dart, lib/features/apliques/domain/entities/stock_aplique.dart -->
