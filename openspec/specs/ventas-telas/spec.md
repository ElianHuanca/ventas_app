---
description: Venta de telas por sucursal. Cubre elegir la sucursal, la lista de ventas por día, el registro con carrito en memoria (selector filtrado por la disponibilidad de la sucursal, fecha, descuento, cálculo de totales y ganancias), el envío en una sola transacción con clave de idempotencia, el detalle de la venta y el borrado de líneas.
---

# Spec: ventas-telas

> Extraído automáticamente por spec-miner. Última extracción: 2026-11-06.
> Fuentes: lib/features/ventas/** (pantallas, cubits/blocs, datasources), lib/features/sucursales/presentation/screens/sucursales_screen.dart, lib/features/telas/infrastructure/datasources/telas_datasource_impl.dart, lib/features/shared/widgets/{data_table_telas,data_table_widget,DialogoDeAlerta,show_snackbar}.dart, supabase/migrations/20261003000100_integridad_stock_y_ventas.sql, supabase/migrations/20261020000000_idempotencia_y_venta_telas.sql
> Last verified: 2026-11-06 (commit 1d15233)

---

### Requirement: Elegir la sucursal para vender telas
<!-- id: SucursalesScreen._buildBody -->
<!-- entities: Sucursal -->
<!-- enforced: SucursalesScreen._buildBody(), SucursalesDatasourceImpl.getSucursales() -->

La pantalla de inicio (entrada "Venta telas" del menú lateral) DEBE mostrar una tarjeta por sucursal activa (`activo = true`), ordenadas por id y con el nombre en mayúsculas; tocar una DEBE abrir las ventas de telas de esa sucursal. En este modo NO DEBE ofrecer la tarjeta "Agregar Sucursal". Mientras cargan las sucursales DEBE mostrar un indicador de carga a pantalla completa.

#### Scenario: Elegir una sucursal
<!-- test: test/features/sucursales/presentation/screens/sucursales_screen_test.dart::inicio (venta de telas) > tocar una sucursal navega a sus ventas -->
- **WHEN** el usuario toca la tarjeta de una sucursal activa
- **THEN** se abre la lista de ventas de telas de esa sucursal

#### Scenario: Sin opción de agregar
<!-- test: test/features/sucursales/presentation/screens/sucursales_screen_test.dart::inicio (venta de telas) > no ofrece la tarjeta para agregar sucursal -->
- **WHEN** se muestra la lista de sucursales para vender
- **THEN** no aparece la tarjeta "Agregar Sucursal"

#### Scenario: Sucursal dada de baja
<!-- test: test/features/sucursales/infrastructure/datasources/sucursales_datasource_impl_test.dart::inicio (venta de telas): una sucursal dada de baja no aparece entre las tarjetas -->
<!-- test: test/features/sucursales/infrastructure/datasources/sucursales_datasource_impl_test.dart::getSucursales no trae las dadas de baja -->
- **WHEN** una sucursal tiene `activo = false`
- **THEN** no aparece entre las tarjetas

---

### Requirement: Listar las ventas de telas de la sucursal por día
<!-- id: VentasDatasourceImpl.getVentas -->
<!-- entities: Venta, Sucursal -->
<!-- enforced: VentasDatasourceImpl.getVentas(), VentasBloc._onLoadRequested(), VentasScreen._buildBody() -->

La lista DEBE mostrar las 10 ventas de telas más recientes de la sucursal (orden por `fecha` descendente), una tarjeta por venta del día con la fecha como d-m-aaaa (sin ceros a la izquierda), y un botón "+" ("Registrar venta"). Mientras carga DEBE mostrar el indicador a pantalla completa. Si la carga falla DEBE quedar la lista vacía sin mensaje de error.

#### Scenario: Sucursal con ventas
<!-- test: test/features/ventas/presentation/screens/ventas_screen_test.dart::muestra una tarjeta por venta con su fecha -->
- **WHEN** la sucursal tiene ventas de telas
- **THEN** se ve una tarjeta por venta (como mucho 10), de la más reciente a la más vieja, con su fecha d-m-aaaa

#### Scenario: Sucursal sin ventas
<!-- test: test/features/ventas/presentation/screens/ventas_screen_test.dart::sin ventas no muestra tarjetas pero sí el botón + -->
- **WHEN** la sucursal no tiene ventas de telas
- **THEN** no hay tarjetas pero sigue el botón "+"

#### Scenario: Falla la carga
<!-- test: test/features/ventas/presentation/bloc/ventas_bloc_test.dart::carga > error del repositorio deja la lista vacía e isLoading en false -->
- **WHEN** la consulta de ventas falla (p. ej. sin conexión)
- **THEN** la lista queda vacía, sin aviso de error

<!-- revisar: un error de carga se ve igual que "sin ventas" (ventas_bloc.dart:68 descarta la excepción) -->

---

### Requirement: Navegar al registro y al detalle desde las ventas de telas
<!-- id: VentasScreen._onCreateVenta -->
<!-- entities: Venta -->
<!-- enforced: VentasScreen._onCreateVenta(), VentasScreen._buildBody() -->

El botón "+" DEBE abrir el registro de venta de telas de la sucursal y tocar una tarjeta DEBE abrir el detalle de esa venta. Al volver de cualquiera de los dos DEBE recargar la lista.

#### Scenario: Registrar y volver
<!-- test: test/features/ventas/presentation/screens/ventas_screen_test.dart::el botón + abre el registro de la sucursal y recarga al volver -->
- **WHEN** el usuario toca "+" y luego vuelve
- **THEN** se abrió el registro de esa sucursal y al volver la lista se recarga

#### Scenario: Abrir el detalle
<!-- test: test/features/ventas/presentation/screens/ventas_screen_test.dart::tap en una tarjeta abre el detalle de esa venta y recarga al volver -->
- **WHEN** el usuario toca la tarjeta de una venta
- **THEN** se abre el detalle de esa venta y al volver la lista se recarga

---

### Requirement: Ofrecer solo las telas disponibles en la sucursal
<!-- id: TelasDatasourceImpl.getTelasPorSucursal -->
<!-- entities: Tela, TelaSucursal, Sucursal -->
<!-- enforced: TelasBloc._onLoadRequested(), TelasDatasourceImpl.getTelasPorSucursal() -->

El selector de telas del registro DEBE ofrecer, si la sucursal tiene al menos un vínculo activo en `tela_sucursales`, solo las telas activas con vínculo activo en esa sucursal; si no tiene ningún vínculo activo (regla de transición) DEBE ofrecer todas las telas activas. En ambos casos DEBE ordenarlas por nombre sin distinguir mayúsculas. Mientras cargan DEBE mostrar un indicador en lugar del selector, los campos Precio y Cantidad y el botón "Añadir".

#### Scenario: Sucursal con disponibilidad configurada
<!-- test: integration_test/flujos/sucursales.dart::la disponibilidad de telas limita lo que ofrece la venta de la sucursal -->
- **WHEN** la sucursal tiene vínculos activos con algunas telas
- **THEN** el selector ofrece solo esas telas (las activas)

#### Scenario: Sucursal sin vínculos activos
<!-- test: integration_test/flujos/sucursales.dart::quitar una tela de la sucursal la saca de la venta; sin ninguna activa vuelve a ofrecer todo el catálogo -->
- **WHEN** la sucursal no tiene ningún vínculo activo
- **THEN** el selector ofrece todo el catálogo de telas activas

---

### Requirement: Elegir la fecha de la venta de telas
<!-- id: DetalleVentaFormCubit.onFechaChanged -->
<!-- entities: Venta -->
<!-- enforced: DetVenta._selectFecha(), DetalleVentaFormCubit.onFechaChanged() -->

El formulario DEBE proponer la fecha y hora en que se abrió, mostrarla como dd/mm/aaaa y permitir elegir otro día en un calendario (de 2020 a 2100). La venta DEBE registrarse en la venta del día elegido. Cancelar el calendario NO DEBE cambiar la fecha.

#### Scenario: Venta con fecha anterior
<!-- test: integration_test/flujos/venta_telas.dart::registra una venta con fecha anterior en la venta de ese día -->
- **WHEN** el usuario elige un día anterior y guarda
- **THEN** las líneas quedan en la venta de ese día de la sucursal (creada si no existía)

#### Scenario: Cancelar el calendario
<!-- test: test/features/ventas/presentation/screens/det_venta_screen_test.dart::cancelar el calendario conserva la fecha -->
- **WHEN** el usuario abre el calendario y lo cancela
- **THEN** la fecha mostrada no cambia

---

### Requirement: Agregar una línea al carrito de telas
<!-- id: DetalleVentaFormCubit.addDetalleVenta -->
<!-- entities: DetalleVenta, Tela -->
<!-- enforced: DetVenta._widget(), DetalleVentaFormCubit.addDetalleVenta() -->

"Añadir" DEBE agregar al principio del carrito (en memoria, sin tocar la base) una línea con la tela elegida, la cantidad en metros y el precio tipeados, su total y sus ganancias, y vaciar los campos Precio y Cantidad. El precio NO se precarga desde la tela. NO DEBE agregar nada, y no muestra mensaje, si no hay tela elegida o si la cantidad o el precio no son números finitos mayores a 0 ("NaN" e "Infinity" no valen). La tabla del carrito muestra Nombre, "Nmts", "PBs", "TBs" y una fila Total con el total del carrito.

#### Scenario: Línea válida
<!-- test: test/features/ventas/presentation/screens/det_venta_screen_test.dart::Añadir agrega la línea con su total y limpia precio y cantidad -->
- **WHEN** hay tela elegida, cantidad 2 y precio 100
- **THEN** el carrito suma una línea de 2 m × 100 Bs = 200 Bs y los campos quedan vacíos

#### Scenario: Sin tela elegida
<!-- test: test/features/ventas/presentation/bloc/detalle_venta_form_cubit_test.dart::addDetalleVenta > no agrega sin producto seleccionado -->
- **WHEN** se toca "Añadir" sin haber elegido una tela
- **THEN** el carrito no cambia

#### Scenario: Cantidad o precio inválidos
<!-- test: test/features/ventas/presentation/bloc/detalle_venta_form_cubit_test.dart::addDetalleVenta > no agrega con cantidad o precio menores o iguales a 0 -->
<!-- test: test/vectores/carritos_vectores_test.dart::telas: los datos inválidos no cambian el carrito y vender bajo el precio de compra da ganancia negativa -->
- **WHEN** la cantidad o el precio son texto, NaN, Infinity, 0 o negativos
- **THEN** el carrito no cambia

<!-- revisar: det_venta_screen.dart:139-143 vacía los campos aunque la línea se rechace, pero el formulario conserva el precio y la cantidad tipeados: el siguiente "Añadir" (p. ej. tras elegir la tela) agrega una línea con valores que ya no se ven -->

---

### Requirement: Sumar la cantidad si se repite tela y precio
<!-- id: DetalleVentaFormCubit.addDetalleVenta#mismo-precio -->
<!-- entities: DetalleVenta, Tela -->
<!-- enforced: DetalleVentaFormCubit.addDetalleVenta() -->

Si el carrito ya tiene una línea de la misma tela al mismo precio, "Añadir" DEBE sumarle la cantidad en vez de crear otra línea y recalcular su total y sus ganancias con la cantidad acumulada. La misma tela a otro precio DEBE ser otra línea.

#### Scenario: Misma tela y precio
<!-- test: test/features/ventas/presentation/bloc/detalle_venta_form_cubit_test.dart::addDetalleVenta > mismo producto y precio hace merge sumando cantidad -->
<!-- test: test/vectores/carritos_vectores_test.dart::telas: la misma tela al mismo precio suma la cantidad sin ruido; a otro precio es otra línea -->
- **WHEN** se agregan 2 m y luego 1 m de la misma tela a 100 Bs
- **THEN** queda una sola línea de 3 m con total 300 Bs

#### Scenario: Misma tela a otro precio
<!-- test: test/features/ventas/presentation/bloc/detalle_venta_form_cubit_test.dart::addDetalleVenta > mismo producto con distinto precio genera líneas separadas -->
<!-- test: test/vectores/carritos_vectores_test.dart::telas: la misma tela al mismo precio suma la cantidad sin ruido; a otro precio es otra línea -->
- **WHEN** se agrega la misma tela a 100 Bs y a 120 Bs
- **THEN** quedan dos líneas

---

### Requirement: Calcular el total y las ganancias de la venta de telas
<!-- id: detalle_venta_form_cubit._centavos -->
<!-- entities: DetalleVenta, Tela -->
<!-- enforced: detalle_venta_form_cubit._centavos(), detalle_venta_form_cubit._sinRuido(), DetalleVentaFormCubit.addDetalleVenta() -->

El total de una línea DEBE ser cantidad × precio redondeado a centavos con la mitad hacia arriba (como `numeric` en Postgres), después de quitar el ruido de coma flotante a 6 decimales. Las ganancias de una línea DEBEN ser (precio − precio de compra de la tela) × cantidad redondeado igual, y 0 si el precio de compra es 0 (pueden quedar negativas si se vende bajo el costo). La cantidad acumulada se redondea a 6 decimales. El total y las ganancias del carrito DEBEN cambiar exactamente lo que cambia cada línea, redondeados a centavos. El descuento NO se resta del total del carrito.

#### Scenario: Mitad del centavo
<!-- test: test/features/ventas/presentation/bloc/detalle_venta_form_cubit_test.dart::addDetalleVenta > la mitad del centavo redondea hacia arriba, como numeric -->
- **WHEN** se agregan 3.75 m a 23.22 Bs
- **THEN** el total de la línea es 87.08 Bs (no 87.07)

#### Scenario: Sin precio de compra
<!-- test: test/features/ventas/presentation/bloc/detalle_venta_form_cubit_test.dart::addDetalleVenta > ganancia es 0 cuando precxcompra es 0 -->
<!-- test: test/vectores/carritos_vectores_test.dart::telas: dos telas distintas, la última queda primera; sin precio de compra la ganancia es 0 -->
- **WHEN** la tela tiene precio de compra 0
- **THEN** las ganancias de la línea son 0

#### Scenario: Acumular sin sumar redondeos
<!-- test: test/features/ventas/presentation/bloc/detalle_venta_form_cubit_test.dart::addDetalleVenta > el merge sube el total lo que sube la línea, sin sumar redondeos -->
<!-- test: test/vectores/carritos_vectores_test.dart::telas: medio metro dos veces a un centavo y quitar todo vuelve a 0 -->
- **WHEN** se agregan dos veces 0.5 m a 0.01 Bs
- **THEN** queda una línea de 1 m con total 0.01, el carrito suma 0.01 y al quitarla vuelve a 0

---

### Requirement: Quitar una línea del carrito de telas
<!-- id: DetalleVentaFormCubit.removeDetalleVenta -->
<!-- entities: DetalleVenta -->
<!-- enforced: DataTableMapTelas, DetalleVentaFormCubit.removeDetalleVenta() -->

El botón "Quitar línea" DEBE sacar del carrito, sin pedir confirmación, la primera línea que coincida en tela, cantidad y precio, y restar su total y sus ganancias del carrito. Si ninguna coincide NO DEBE cambiar nada. Una línea quitada NO DEBE registrarse al guardar.

#### Scenario: Quitar entre líneas parecidas
<!-- test: test/features/ventas/presentation/bloc/detalle_venta_form_cubit_test.dart::removeDetalleVenta > con líneas parecidas quita solo la que coincide en tela, cantidad y precio -->
- **WHEN** hay líneas de la misma tela a otro precio y de otra tela al mismo precio, y se quita una
- **THEN** solo sale la que coincide en tela, cantidad y precio, y el total baja su importe

#### Scenario: Línea quitada no se registra
<!-- test: integration_test/flujos/venta_telas.dart::una línea quitada del carrito no se registra y el descuento queda en la venta -->
- **WHEN** se quita una línea y se guarda
- **THEN** la base no tiene esa línea y la venta guarda el descuento

---

### Requirement: Registrar la venta de telas en una sola operación
<!-- id: DetalleVentaFormCubit.onFormSubmit -->
<!-- entities: Venta, DetalleVenta -->
<!-- depends_on: Agregar una línea al carrito de telas -->
<!-- triggers: Acumular en la venta de telas del día de la sucursal -->
<!-- enforced: DetVenta._widget(), DetalleVentaFormCubit.onFormSubmit(), VentasDatasourceImpl.registrarVentaTelas() -->

"Guardar" DEBE enviar el carrito entero en una sola llamada (`registrar_venta_telas`) con la sucursal, la fecha elegida (ISO 8601 completa), las líneas (tela, nombre, precio, cantidad, total, ganancias), el descuento (vacío = 0) y la clave de operación. Con éxito DEBE avisar "Realizado correctamente" y volver a la lista de ventas. Si el carrito está vacío o el descuento no es un número finito NO DEBE enviar nada y DEBE avisar "Hubo un error". Si el envío falla DEBE avisar "Hubo un error", quedarse en el formulario y conservar el carrito para reintentar.

#### Scenario: Venta registrada
<!-- test: test/features/ventas/presentation/screens/det_venta_screen_test.dart::al guardar con éxito vuelve a la pantalla anterior -->
- **WHEN** el carrito tiene líneas, el descuento es válido y la base responde bien
- **THEN** se avisa "Realizado correctamente" y se vuelve a la lista de ventas

#### Scenario: Carrito vacío
<!-- test: test/features/ventas/presentation/screens/det_venta_screen_test.dart::Guardar sin líneas avisa "Hubo un error" y no llama repos -->
- **WHEN** se toca "Guardar" sin líneas
- **THEN** se avisa "Hubo un error" y no se envía nada

#### Scenario: Descuento inválido
<!-- test: test/features/ventas/presentation/bloc/detalle_venta_form_cubit_test.dart::onFormSubmit > descuento NaN devuelve false sin escribir nada -->
- **WHEN** el descuento no es un número finito
- **THEN** se avisa "Hubo un error" y no se envía nada

#### Scenario: Sin conexión
<!-- test: red/venta_telas_test.dart::registrar > sin conexión: falla limpia (no llega nada a la base), conserva el carrito y el reintento con señal vende una vez -->
- **WHEN** el envío falla antes de llegar a la base
- **THEN** se avisa "Hubo un error", el carrito sigue y el siguiente "Guardar" con señal vende una sola vez

<!-- revisar: ni la app ni la base comparan el descuento con el total (detalle_venta_form_cubit.dart:176; `ventas` no tiene CHECK de total >= 0): una venta de telas puede quedar con descuento mayor que su total, cosa que la venta de apliques sí bloquea -->

---

### Requirement: Ignorar el doble toque en Guardar de la venta de telas
<!-- id: DetalleVentaFormCubit.enviando -->
<!-- entities: Venta -->
<!-- enforced: DetVenta._widget(), DetalleVentaFormCubit.onFormSubmit() -->

Mientras un envío está en curso, otro "Guardar" NO DEBE volver a enviar la venta: la pantalla ignora el toque y un envío concurrente devuelve falso sin llamar a la base.

#### Scenario: Doble toque
<!-- test: test/features/ventas/presentation/bloc/detalle_venta_form_cubit_test.dart::onFormSubmit > un segundo envío mientras se guarda no registra la venta dos veces -->
- **WHEN** se toca "Guardar" dos veces antes de que responda la base
- **THEN** la venta se envía una sola vez

---

### Requirement: Reusar la clave de operación al reintentar la venta de telas
<!-- id: DetalleVentaFormCubit._clave -->
<!-- entities: Venta -->
<!-- enforced: DetalleVentaFormCubit.onFormSubmit(), ClaveDeOperacion.para(), ClaveDeOperacion.descartar() -->

La clave de operación DEBE quedar atada a lo que se envía: líneas, descuento y día (aaaa-mm-dd de la fecha elegida). Reintentar el mismo envío DEBE llevar la misma clave; agregar, quitar o cambiar una línea, cambiar el descuento o cambiar de día DEBE generar otra. Otra hora del mismo día NO cambia la clave, y agregar y quitar la misma línea deja el mismo envío. Después de un envío exitoso la clave DEBE descartarse.

#### Scenario: Reintento tras respuesta perdida
<!-- test: red/venta_telas_test.dart::registrar > respuesta perdida y el usuario vuelve a tocar Guardar: la línea no se duplica y el total coincide con las líneas -->
- **WHEN** la base aplicó la venta pero la respuesta se perdió y el usuario vuelve a tocar "Guardar"
- **THEN** el reintento lleva la misma clave y la venta queda aplicada una sola vez

#### Scenario: Nueva venta después de una exitosa
<!-- test: red/venta_telas_test.dart::registrar > después del reintento que salió bien, otra venta el mismo día se suma aparte (la clave se renueva) -->
- **WHEN** después de una venta exitosa se registra otra igual el mismo día
- **THEN** lleva otra clave y se suma a la venta del día

#### Scenario: Otro día u otra hora
<!-- test: test/features/ventas/presentation/bloc/detalle_venta_form_cubit_test.dart::clave de operación > otro día es otro envío; otra hora del mismo día, no -->
- **WHEN** tras una falla se cambia la fecha a otro día, o solo la hora del mismo día
- **THEN** otro día lleva otra clave; otra hora conserva la clave

---

### Requirement: Acumular en la venta de telas del día de la sucursal
<!-- id: 20261020000000_idempotencia_y_venta_telas.sql:registrar_venta_telas -->
<!-- entities: Venta, DetalleVenta, Sucursal -->
<!-- enforced: 20261020000000_idempotencia_y_venta_telas.sql:registrar_venta_telas, 20261003000100_integridad_stock_y_ventas.sql:ventas_sucursal_dia_key -->

En una sola transacción la base DEBE: crear la venta del día de la sucursal (día = primeros 10 caracteres de `fecha`) o reusar la existente sin tocar su `fecha` (queda la del primer registro); sumarle como total y ganancias la suma de los totales y ganancias de las líneas recibidas redondeados a 2 decimales (los calcula la base, no se reciben aparte) y sumarle el descuento; acumular cada línea por (venta, tela, precio) sumando cantidad, total y ganancias (una línea vieja con total o ganancias NULL suma desde 0); y devolver el id de la venta. Lo que sumó otro dispositivo se conserva.

#### Scenario: Primera venta del día
<!-- test: supabase/tests/database/04_rpc_ventas_telas.test.sql::crea la venta del día con el total y las ganancias de sus líneas y el descuento -->
- **WHEN** la sucursal no tiene venta de telas ese día
- **THEN** se crea con total y ganancias = suma de las líneas y el descuento recibido

#### Scenario: Otro registro el mismo día
<!-- test: supabase/tests/database/04_rpc_ventas_telas.test.sql::suma total, ganancias y descuento a la venta del día y conserva la fecha del primer registro -->
- **WHEN** se registra otra venta el mismo día a otra hora
- **THEN** se devuelve la misma venta, se le suman total, ganancias y descuento y su fecha sigue siendo la del primer registro

#### Scenario: Línea repetida
<!-- test: supabase/tests/database/04_rpc_ventas_telas.test.sql::la misma tela+precio acumula en su línea; otro precio es otra línea -->
- **WHEN** llega una línea de una tela y precio que la venta ya tiene (o repetida en el mismo envío)
- **THEN** se suma a esa línea; otro precio crea otra línea

#### Scenario: Total con más de 2 decimales
<!-- test: supabase/tests/database/04_rpc_ventas_telas.test.sql::la venta suma el total de la línea tal como quedó guardado (redondeado a centavos) -->
- **WHEN** una línea trae un total con más de 2 decimales
- **THEN** la línea lo guarda redondeado y la venta suma ese mismo valor redondeado

#### Scenario: Varios dispositivos a la vez
<!-- test: concurrencia/venta_telas_test.dart::registrar_venta_telas desde $cantidadDispositivos dispositivos a la vez en una sucursal sin venta del día -->
- **WHEN** 8 dispositivos registran la misma tela y precio a la vez en una sucursal sin venta del día
- **THEN** queda una venta y una línea con todo sumado, y el total de la venta es igual al de la línea

---

### Requirement: Rechazar envíos inválidos de venta de telas
<!-- id: 20261020000000_idempotencia_y_venta_telas.sql:registrar_venta_telas#validaciones -->
<!-- entities: Venta, DetalleVenta, Tela -->
<!-- enforced: 20261020000000_idempotencia_y_venta_telas.sql:registrar_venta_telas, 20261003000100_integridad_stock_y_ventas.sql:detalle_ventas_montos_check -->

La base DEBE rechazar el envío entero, sin dejar venta del día, líneas ni totales, si: no trae líneas, `p_detalles` es NULL o no es un arreglo ("La venta no tiene líneas"); el descuento es negativo ("El descuento no puede ser negativo"); una línea no trae total o ganancias ("Línea sin total o ganancias: <nombre>"); una cantidad es 0 o negativa o un precio es negativo (CHECK); o la tela no existe (FK). Estas validaciones se hacen antes de mirar la clave de operación.

#### Scenario: Descuento negativo
<!-- test: supabase/tests/database/04_rpc_ventas_telas.test.sql::rechaza un descuento negativo -->
- **WHEN** llega un descuento menor a 0
- **THEN** la base lanza "El descuento no puede ser negativo" y no guarda nada

#### Scenario: Línea sin total
<!-- test: supabase/tests/database/04_rpc_ventas_telas.test.sql::rechaza una línea sin total (la venta no podría sumar lo mismo que sus líneas) -->
- **WHEN** una línea no trae total o ganancias
- **THEN** se rechaza el envío entero

#### Scenario: Una línea inválida entre válidas
<!-- test: supabase/tests/database/04_rpc_ventas_telas.test.sql::los envíos rechazados no dejaron venta del día, líneas ni totales (tampoco la línea válida que venía antes) -->
- **WHEN** un envío trae una línea válida seguida de una con cantidad 0
- **THEN** no queda nada guardado, tampoco la línea válida

---

### Requirement: Ver el detalle de una venta de telas
<!-- id: DetVentas.build -->
<!-- entities: Venta, DetalleVenta -->
<!-- enforced: DetVentas.build(), VentaBloc._onLoadRequested(), DetalleVentasBloc._onLoadRequested(), dataTableWidget() -->

El detalle DEBE mostrar como título la fecha de la venta (d-m-aaaa) y una tabla con Tela, Cantidad ("Nmts"), Precio ("PBs"), Total ("T Bs") y un botón de borrar por línea, más las filas "Total" (total guardado de la venta) y "Descuento" (descuento de la venta). Las ganancias NO se muestran. Mientras carga la venta o sus líneas DEBE mostrar el indicador a pantalla completa. Sin líneas DEBE mostrar "Lista Vacia". Si la venta no se pudo cargar DEBE mostrar "No se pudo cargar. Revisá la conexión y volvé a intentar." con título "Venta" y botón para volver.

#### Scenario: Venta con líneas
<!-- test: test/features/ventas/presentation/screens/det_ventas_screen_test.dart::muestra la fecha como título, las líneas y los totales -->
- **WHEN** se abre una venta con líneas
- **THEN** se ven la fecha como título, cada línea y las filas Total y Descuento

#### Scenario: Venta sin líneas
<!-- test: test/features/ventas/presentation/screens/det_ventas_screen_test.dart::venta sin líneas muestra "Lista Vacia" -->
- **WHEN** la venta no tiene líneas (o falló solo la carga de las líneas)
- **THEN** se ve "Lista Vacia"

#### Scenario: Venta que no carga
<!-- test: test/features/ventas/presentation/screens/det_ventas_screen_test.dart::si la venta no se pudo cargar no rompe la pantalla -->
- **WHEN** la consulta de la venta falla
- **THEN** se ve el aviso de carga fallida con opción de volver

<!-- revisar: las líneas se leen sin ORDER BY (detalleVentas_datasource_impl.dart:13): su orden en pantalla no está definido -->

---

### Requirement: Borrar una línea de una venta registrada
<!-- id: DetalleVentasBloc.deleteDetVenta -->
<!-- entities: DetalleVenta, Venta -->
<!-- triggers: Descontar la línea borrada del total de la venta -->
<!-- enforced: dataTableWidget(), dialogoDeAlerta(), DetalleVentasBloc.deleteDetVenta(), DetalleVentasDatasourceImpl.borrarDetalleVenta(), VentaBloc.mostrarVenta() -->

El botón "Eliminar línea" DEBE pedir confirmación ("Confirmar Eliminación" / "¿Está seguro de que desea eliminar este elemento?", con "Cancelar" y "Eliminar"). Al confirmar DEBE borrar la línea en una sola llamada (`borrar_detalle_venta`) y sacarla de la pantalla recién cuando la base respondió, mostrando el total y el descuento que devolvió la base. Si la base indica que la línea ya no estaba DEBE sacarla igual y volver a leer la venta. Si la llamada falla la línea DEBE seguir en pantalla con el total de antes, para volver a borrarla.

#### Scenario: Confirmar el borrado
<!-- test: test/features/ventas/presentation/screens/det_ventas_screen_test.dart::borrar una línea pide confirmación, la quita y muestra el total que dejó la base -->
- **WHEN** el usuario toca borrar en una línea y confirma
- **THEN** la línea desaparece y el Total muestra el valor que devolvió la base

#### Scenario: Cancelar
<!-- test: test/features/ventas/presentation/screens/det_ventas_screen_test.dart::Cancelar en la confirmación no borra nada -->
- **WHEN** el usuario cancela la confirmación
- **THEN** no se borra nada

#### Scenario: Sin señal
<!-- test: test/features/ventas/presentation/screens/det_ventas_screen_test.dart::si borrar falla (sin señal) la línea sigue en la tabla con el total de antes, para volver a borrarla -->
- **WHEN** la llamada de borrado falla
- **THEN** la línea y el total siguen como estaban

#### Scenario: Reintento tras respuesta perdida
<!-- test: red/venta_telas_test.dart::borrar una línea > respuesta perdida y el usuario vuelve a borrarla: no descuenta dos veces, la línea sale de la pantalla y se ve el total de la base -->
- **WHEN** la base borró la línea pero la respuesta se perdió y el usuario vuelve a borrarla
- **THEN** no se descuenta dos veces, la línea sale de la pantalla y se ve el total de la base

<!-- revisar: un borrado fallido no muestra ningún aviso (det_ventas_screen.dart:39 descarta el resultado de deleteDetVenta) -->

---

### Requirement: Descontar la línea borrada del total de la venta
<!-- id: 20261020000000_idempotencia_y_venta_telas.sql:borrar_detalle_venta -->
<!-- entities: DetalleVenta, Venta -->
<!-- enforced: 20261020000000_idempotencia_y_venta_telas.sql:borrar_detalle_venta -->

En una sola transacción la base DEBE borrar la línea y restar su total y sus ganancias (NULL cuenta como 0) de la venta, y devolver la venta con los totales ya descontados. Si la línea ya no existe NO DEBE hacer nada y DEBE devolver NULL (idempotente sin clave). El descuento de la venta NO cambia y la venta NO se borra aunque quede sin líneas.

#### Scenario: Borrar una línea
<!-- test: supabase/tests/database/04_rpc_ventas_telas.test.sql::borra la línea y devuelve la venta con su total y sus ganancias descontados -->
- **WHEN** se borra una línea existente
- **THEN** la línea desaparece y la venta queda con la suma de las líneas que siguen

#### Scenario: Línea que ya no existe
<!-- test: supabase/tests/database/04_rpc_ventas_telas.test.sql::el segundo borrado no vuelve a descontar el total -->
- **WHEN** se pide borrar una línea ya borrada (reintento u otro dispositivo)
- **THEN** devuelve NULL y no descuenta nada

---

### Requirement: Borrar una venta de telas vacía
<!-- id: VentasBloc.deleteVentaIfEmpty -->
<!-- entities: Venta -->
<!-- enforced: VentasBloc.deleteVentaIfEmpty(), VentasDatasourceImpl.deleteVenta() -->

La operación DEBE leer la venta y borrarla físicamente (sus líneas se van por la FK en cascada) solo si su total es 0; con total distinto de 0 NO DEBE borrarla. Cualquier error se ignora.

#### Scenario: Venta en cero
<!-- test: test/features/ventas/presentation/bloc/ventas_bloc_test.dart::deleteVentaIfEmpty > borra la venta si su total es 0 -->
- **WHEN** se pide borrar una venta con total 0
- **THEN** la venta se borra

#### Scenario: Venta con total
<!-- test: test/features/ventas/presentation/bloc/ventas_bloc_test.dart::deleteVentaIfEmpty > no borra la venta si tiene total -->
- **WHEN** la venta tiene total distinto de 0
- **THEN** no se borra

<!-- revisar: ninguna pantalla invoca VentasBloc.deleteVentaIfEmpty (ventas_bloc.dart:50): una venta a la que se le borraron todas las líneas sigue en la lista con total 0 (y su descuento) -->

---

### Invariant: Una sola venta de telas por sucursal y día
<!-- entities: Venta, Sucursal -->
<!-- enforced: 20261003000100_integridad_stock_y_ventas.sql:ventas_sucursal_dia_key -->
<!-- verified_by: supabase/tests/database/05_restricciones.test.sql::ventas: una sola venta de telas por sucursal y día (aunque cambie la hora) -->

La tabla `ventas` NO DEBE tener dos filas con la misma sucursal y el mismo día (primeros 10 caracteres de `fecha`), aunque cambie la hora.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Una línea por venta, tela y precio
<!-- entities: DetalleVenta -->
<!-- enforced: 20261003000100_integridad_stock_y_ventas.sql:detalle_ventas_linea_key -->
<!-- verified_by: supabase/tests/database/05_restricciones.test.sql::detalle_ventas: una línea por venta+tela+precio -->

La tabla `detalle_ventas` NO DEBE tener dos líneas con la misma venta, tela y precio.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: El total de la venta de telas es la suma de sus líneas
<!-- entities: Venta, DetalleVenta -->
<!-- enforced: 20261020000000_idempotencia_y_venta_telas.sql:registrar_venta_telas, 20261020000000_idempotencia_y_venta_telas.sql:borrar_detalle_venta -->
<!-- verified_by: supabase/tests/database/04_rpc_ventas_telas.test.sql::la venta queda con la suma de las líneas que siguen -->

Las escrituras de esta app (registrar y borrar líneas) DEBEN dejar el total y las ganancias de la venta iguales a la suma de los de sus líneas, también con varios dispositivos y con respuestas perdidas.

> Last verified: 2026-11-06 (commit 1d15233)

<!-- revisar: no lo garantiza la base: registrar_detalle_venta + incrementar_venta (flujo de Android/iOS) reciben los totales del cliente y pueden descuadrarlo -->

---

### Invariant: Montos de la venta de telas no negativos
<!-- entities: Venta, DetalleVenta -->
<!-- enforced: 20261003000100_integridad_stock_y_ventas.sql:detalle_ventas_montos_check, 20261003000100_integridad_stock_y_ventas.sql:ventas_descuento_no_negativo -->
<!-- verified_by: supabase/tests/database/05_restricciones.test.sql::detalle_ventas: no acepta cantidad 0 -->

Cada línea DEBE tener cantidad > 0 y precio >= 0, y cada venta descuento >= 0. No hay restricción sobre el total de la venta ni sobre el total o las ganancias de las líneas.

> Last verified: 2026-11-06 (commit 1d15233)

<!-- uncertainty: VentasBloc.createVenta, VentasDatasourceImpl.createVenta/createVentaAhora/getVentaByFecha/actualizarVenta y DetalleVentasBloc.createDetVenta no los usa ninguna pantalla (quedan para armar datos); no se describen como comportamiento observable -->
<!-- uncertainty: detalle_ventas.cantidad y precio son numeric(12,2): la base redondea a 2 decimales una cantidad tipeada con más (0.125 m), mientras el total de la línea se calculó con la cantidad completa; no hay test que lo fije -->
<!-- uncertainty: la fecha se envía como hora local sin zona (DateTime.toIso8601String): el "día" de la venta es el día local del dispositivo -->
<!-- deferred: lib/features/ventas/infrastructure/mappers/detalleVenta_mapper.dart, lib/features/ventas/domain/entities/detalleVenta.dart, lib/features/ventas/infrastructure/errors/venta_errors.dart, lib/features/ventas/infrastructure/errors/detalleVenta_errors.dart, lib/features/ventas/infrastructure/repositories/ventas_repository_impl.dart, lib/features/ventas/infrastructure/repositories/detalleVentas_repository_impl.dart, lib/features/shared/screens/screen1.dart -->
