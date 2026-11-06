---
description: Inventario de apliques por sucursal para el fabricante. Cubre elegir la sucursal, la consulta del inventario activo con lo vendido en las últimas 4 semanas (propio y promedio de otras sucursales), la regla de reposición (mínimo, cuánto hacer, estimación sin ventas propias), el filtro Faltan/Todos, el orden para el fabricante, y el envío de la lista como PDF (con saneo Latin-1) o como texto copiado.
---

# Spec: inventario

> Extraído automáticamente por spec-miner. Última extracción: 2026-11-06.
> Fuentes: lib/features/apliques/domain/{reposicion,pdf_faltantes,mensaje_faltantes}.dart, lib/features/apliques/domain/entities/stock_con_ventas.dart, lib/features/apliques/presentation/bloc/inventario_cubit.dart, lib/features/apliques/presentation/screens/{inventario,inventario_sucursales}_screen.dart, lib/features/apliques/infrastructure/datasources/apliques_datasource_impl.dart, lib/features/apliques/infrastructure/mappers/stock_con_ventas_mapper.dart, supabase/migrations/20261015000000_inventario_con_ventas.sql
> Last verified: 2026-11-06 (commit 1d15233)

---

### Requirement: Elegir la sucursal del inventario
<!-- id: InventarioSucursalesScreen._buildBody -->
<!-- entities: Sucursal -->
<!-- enforced: InventarioSucursalesScreen._buildBody(), SucursalesDatasourceImpl.getSucursales() -->

La pantalla "Inventario" (menú lateral, después de Fabricación) DEBE mostrar una tarjeta por sucursal activa, sin botón atrás; tocar una DEBE abrir el inventario de esa sucursal. Mientras cargan DEBE mostrar el indicador a pantalla completa.

#### Scenario: Elegir una sucursal
<!-- test: test/features/apliques/presentation/screens/inventario_sucursales_screen_test.dart::tocar una sucursal abre su inventario (push) -->
- **WHEN** el usuario toca una sucursal
- **THEN** se abre el inventario de esa sucursal

---

### Requirement: Consultar el inventario con lo vendido
<!-- id: 20261015000000_inventario_con_ventas.sql:inventario_con_ventas -->
<!-- entities: StockConVentas, Inventario, Aplique, ColorItem, ApliqueColor -->
<!-- enforced: 20261015000000_inventario_con_ventas.sql:inventario_con_ventas, ApliquesDatasourceImpl.getInventarioConVentas(), StockConVentasMapper.jsonToEntity() -->

La base DEBE devolver, solo leyendo, las filas de inventario activas de la sucursal cuyo aplique, color y vínculo `aplique_colores` están activos, ordenadas por nombre de aplique y de color, con: aplique, color, hex ("" si no tiene), stock; `vendidas` = unidades vendidas en esa sucursal con `fecha` entre desde y hasta inclusive, comparando como texto ISO 8601; y `vendidas_otras` = lo vendido de ese aplique+color en las otras sucursales dividido por cuántas otras sucursales vendieron algún aplique en el rango. Sin ventas DEBE dar 0, nunca NULL.

#### Scenario: Filtros como la venta
<!-- test: supabase/tests/database/08_inventario_con_ventas.test.sql::deja afuera un color con el vínculo aplique_colores inactivo -->
- **WHEN** una fila de inventario, su aplique, su color o su vínculo está inactivo, o el color nunca se vinculó
- **THEN** la fila no se devuelve

#### Scenario: Promedio de las otras
<!-- test: supabase/tests/database/08_inventario_con_ventas.test.sql::con 2 otras sucursales, la que no vendió en el rango no baja el promedio (6 / 1, no 6 / 2) -->
- **WHEN** de dos otras sucursales solo una vendió apliques en el rango (6 unidades)
- **THEN** `vendidas_otras` es 6

#### Scenario: Bordes del rango
<!-- test: supabase/tests/database/08_inventario_con_ventas.test.sql::compara fecha como texto: hasta "…T23:59:59" deja afuera "…T23:59:59.500" -->
- **WHEN** una venta tiene fecha "…T23:59:59.500" y hasta es "…T23:59:59"
- **THEN** no cuenta (la comparación es de texto)

---

### Requirement: Mirar las ventas de las últimas 4 semanas
<!-- id: InventarioCubit.cargar -->
<!-- entities: StockConVentas -->
<!-- enforced: InventarioCubit.cargar(), ApliquesDatasourceImpl.getInventarioConVentas() -->

La pantalla DEBE pedir las ventas desde hace 27 días a las 00:00:00.000 hasta hoy a las 23:59:59.999999 (28 días, hoy incluido), con "hoy" tomado en cada carga; recargar otro día DEBE usar la fecha y la ventana nuevas.

#### Scenario: Ventana
<!-- test: test/features/apliques/presentation/bloc/inventario_cubit_test.dart::al crearse carga las ventas de las últimas 4 semanas, hoy incluido -->
- **WHEN** se abre el inventario el 2026-10-28
- **THEN** se consultan las ventas del 2026-10-01T00:00:00.000 al 2026-10-28T23:59:59.999999

---

### Requirement: Calcular el mínimo y cuánto hacer
<!-- id: Reposicion.de -->
<!-- entities: Reposicion, StockConVentas -->
<!-- enforced: Reposicion.de(), ReglaReposicion -->

Para cada aplique+color, con `vendidas` = lo vendido en la ventana (o la estimación, ver abajo): venta semanal = vendidas / 4; mínimo = ⌈vendidas × 2.5 / 4⌉ (1.5 semanas de entrega + 1 de colchón); si stock <= mínimo, hacer = ⌈2 × mínimo − stock⌉, si no 0. Es faltante si hacer > 0. Lo que no se vendió en la ventana tiene mínimo 0 y NO DEBE pedirse.

#### Scenario: Caso típico
<!-- test: test/features/apliques/domain/reposicion_test.dart::Reposicion.de > el caso de Ramada: vende 9 por semana y quedan 3 -->
- **WHEN** se vendieron 36 en 4 semanas (9 por semana) y quedan 3
- **THEN** el mínimo es 23 y hay que hacer 43

#### Scenario: Stock igual al mínimo
<!-- test: test/features/apliques/domain/reposicion_test.dart::Reposicion.de > falta con el stock igual al mínimo, no con uno más -->
- **WHEN** el stock es igual al mínimo
- **THEN** falta; con una unidad más, no

#### Scenario: Sin ventas
<!-- test: test/features/apliques/domain/reposicion_test.dart::Reposicion.de > lo que no se vendió en la ventana no falta, aunque esté en 0 -->
- **WHEN** un aplique+color no se vendió en la ventana aunque tenga stock 0
- **THEN** no es faltante

#### Scenario: Stock con decimales
<!-- test: test/features/apliques/domain/reposicion_test.dart::Reposicion.de > con stock con decimales, lo que hay que hacer redondea para arriba -->
- **WHEN** el stock tiene decimales
- **THEN** lo que hay que hacer se redondea hacia arriba

---

### Requirement: Estimar con las otras sucursales si la sucursal no vendió
<!-- id: ReglaReposicion.aplicar -->
<!-- entities: Reposicion, StockConVentas -->
<!-- enforced: ReglaReposicion.aplicar(), _AvisoEstimada.build(), _Fila.build() -->

Si ningún aplique+color de la sucursal tiene ventas propias en la ventana, la regla DEBE usar `vendidas_otras` para todos y la pantalla DEBE avisar "Esta tienda no vendió apliques en las últimas 4 semanas: se estima con lo que venden las otras." y mostrar "se estiman N por semana" en cada fila. Con alguna venta propia NO DEBE estimar (ignora a las otras).

#### Scenario: Tienda nueva
<!-- test: test/features/apliques/presentation/screens/inventario_screen_test.dart::una tienda sin ventas propias avisa que es una estimación -->
- **WHEN** la sucursal no vendió nada en 4 semanas y otras sí
- **THEN** se calculan los faltantes con lo de las otras y se ve el aviso de estimación

#### Scenario: Con alguna venta propia
<!-- test: test/features/apliques/domain/reposicion_test.dart::ReglaReposicion.aplicar > con alguna venta propia no estima: ignora a las otras -->
- **WHEN** la sucursal vendió al menos un aplique+color
- **THEN** se usan solo sus ventas

---

### Requirement: Ordenar para el fabricante
<!-- id: ReglaReposicion.porAplique -->
<!-- entities: Reposicion -->
<!-- enforced: ReglaReposicion.aplicar(), ReglaReposicion.porAplique(), pdf_faltantes.ordenParaFabricante() -->

La pantalla DEBE listar primero los faltantes y después el resto; cada parte, por aplique A→Z sin distinguir mayúsculas, dentro de cada aplique de lo que más hay que hacer a lo que menos, y a igual cantidad por color sin distinguir mayúsculas. El PDF y el texto copiado DEBEN usar ese mismo orden para los faltantes.

#### Scenario: Orden de la pantalla
<!-- test: test/features/apliques/domain/reposicion_test.dart::ReglaReposicion.aplicar > faltantes primero, por aplique y de más a menos para hacer -->
- **WHEN** hay faltantes y no faltantes de varios apliques
- **THEN** primero van los faltantes por aplique A→Z y de más a menos para hacer

#### Scenario: Orden del fabricante
<!-- test: test/features/apliques/domain/pdf_faltantes_test.dart::ordenParaFabricante > ignora mayúsculas y a igual cantidad ordena por color -->
- **WHEN** dos colores del mismo aplique tienen igual cantidad a hacer
- **THEN** se ordenan por color sin distinguir mayúsculas

---

### Requirement: Filtrar entre Faltan y Todos
<!-- id: InventarioCubit.toggleSoloFaltantes -->
<!-- entities: Reposicion -->
<!-- enforced: InventarioCubit.toggleSoloFaltantes(), InventarioState.visibles, _Cuerpo.build() -->

El selector "Faltan (N) | Todos (M)" DEBE mostrar por defecto solo los faltantes y alternar a todo el inventario; recargar DEBE conservar el filtro. Con "Faltan" elegido y ningún faltante DEBE mostrar "Tocá "Todos" para ver el stock de cada color.".

#### Scenario: Ver todos
<!-- test: test/features/apliques/presentation/screens/inventario_screen_test.dart::"Todos" agrega lo que sobra y lo que no se vende -->
- **WHEN** el usuario elige "Todos"
- **THEN** se ven también los que alcanzan y los que no se venden

#### Scenario: Recargar conserva el filtro
<!-- test: test/features/apliques/presentation/bloc/inventario_cubit_test.dart::recargar mantiene el filtro elegido -->
- **WHEN** se recarga con "Todos" elegido
- **THEN** sigue en "Todos"

---

### Requirement: Mostrar el resumen y cada aplique y color
<!-- id: _Fila.build -->
<!-- entities: Reposicion -->
<!-- enforced: _Resumen.build(), _Fila.build(), _Cuerpo.build(), mensaje_faltantes.cantidadLegible() -->

El encabezado DEBE decir "Inventario" y el nombre de la sucursal. El resumen DEBE decir "N para reponer" ("1 para reponer") y "Hacer T en total", o "No falta nada" y "Todo alcanza para más de 2.5 semanas de venta.". Cada fila DEBE mostrar la muestra del color, el aplique, "Color · vende X por semana" (o "se estiman X por semana", o "sin ventas en 4 semanas"), "Quedan S" (entero sin decimales, si no con dos) más " · mínimo M" si el mínimo es mayor a 0, y "Hacer N" si falta. Al pie DEBE explicar la regla.

#### Scenario: Faltantes
<!-- test: test/features/apliques/presentation/screens/inventario_screen_test.dart::muestra la sucursal, el resumen y solo los faltantes -->
- **WHEN** hay aplique+color que faltan
- **THEN** se ven el resumen con cuántos reponer y el total a hacer, y cada faltante con "Hacer N"

#### Scenario: No falta nada
<!-- test: test/features/apliques/presentation/screens/inventario_screen_test.dart::si no falta nada lo dice y no deja enviar ni copiar -->
- **WHEN** nada falta
- **THEN** se ve "No falta nada" y no se puede compartir ni copiar

---

### Requirement: Avisar la carga, el error y el inventario vacío
<!-- id: _Cuerpo.build -->
<!-- entities: StockConVentas -->
<!-- enforced: InventarioCubit.cargar(), _Cuerpo.build() -->

Mientras carga DEBE mostrar un indicador y no dejar compartir ni copiar. Si la carga falla DEBE mostrar "No se pudo cargar el inventario. Revisá la conexión." con "Reintentar" (no "No falta nada"). Si la sucursal no tiene filas DEBE mostrar "Esta tienda no tiene apliques en el inventario.".

#### Scenario: Sin conexión
<!-- test: test/features/apliques/presentation/screens/inventario_screen_test.dart::sin conexión avisa del error y reintentar recupera -->
- **WHEN** la consulta falla y luego el usuario toca "Reintentar" con señal
- **THEN** primero se ve el aviso de error y después el inventario

#### Scenario: Inventario vacío
<!-- test: test/features/apliques/presentation/screens/inventario_screen_test.dart::sin apliques en el inventario lo dice (no "no falta nada") -->
- **WHEN** la sucursal no tiene apliques en el inventario
- **THEN** se ve "Esta tienda no tiene apliques en el inventario."

---

### Requirement: Compartir el PDF de faltantes
<!-- id: InventarioScreen._compartir -->
<!-- entities: Reposicion, Sucursal -->
<!-- enforced: InventarioScreen._compartir(), compartirPdfSistema(), pdf_faltantes.nombrePdfFaltantes() -->

"Compartir PDF" DEBE estar habilitado solo si hay faltantes y no está cargando. DEBE armar el PDF de los faltantes y abrir la hoja de compartir del sistema con el archivo `faltantes_<sucursal>_<aaaa-mm-dd>.pdf` (sucursal en minúsculas, lo que no es a-z ni 0-9 pasa a "_", sin "_" en los bordes; "sucursal" si queda vacío; si el nombre de la sucursal no se conoce se usa "sucursal <id>"). Si el sistema no puede compartir DEBE avisar "No se pudo compartir el PDF: usá "Copiar lista"".

#### Scenario: Compartir
<!-- test: test/features/apliques/presentation/screens/inventario_screen_test.dart::"Compartir PDF" comparte el PDF de faltantes de la sucursal -->
- **WHEN** hay faltantes y se toca "Compartir PDF" en la sucursal "Ramada" el 2026-10-05
- **THEN** se comparte "faltantes_ramada_2026-10-05.pdf"

#### Scenario: No se puede compartir
<!-- test: test/features/apliques/presentation/screens/inventario_screen_test.dart::si no se puede compartir, avisa que se puede copiar -->
- **WHEN** la hoja de compartir del sistema falla
- **THEN** se avisa que se puede usar "Copiar lista"

---

### Requirement: Armar el PDF de faltantes
<!-- id: pdf_faltantes.pdfFaltantes -->
<!-- entities: Reposicion -->
<!-- enforced: pdf_faltantes.pdfFaltantes() -->

El PDF (A4) DEBE llevar "Huantex", "Faltantes de apliques", la sucursal y la fecha dd/mm/aaaa; una tabla Aplique | Color | Quedan | Hacer en el orden para el fabricante, con el nombre del aplique solo en la primera fila de su grupo, la muestra del color (un círculo vacío si el hex no es válido) y fondo alternado por aplique; el encabezado de la tabla se repite en cada página; al final "N apliques, M colores" y "Total a hacer: T"; pie "Página X de Y" y, desde la segunda página, un encabezado con sucursal y fecha. Sin faltantes igual DEBE armarse (total 0).

#### Scenario: Lista larga
<!-- test: test/features/apliques/domain/pdf_faltantes_test.dart::pdfFaltantes > una lista larga sigue en más páginas -->
- **WHEN** los faltantes no entran en una página
- **THEN** la tabla sigue en más páginas

#### Scenario: Hex inválido
<!-- test: test/features/apliques/domain/pdf_faltantes_test.dart::pdfFaltantes > un hex vacío o inválido no rompe el PDF -->
- **WHEN** un color no tiene hex válido
- **THEN** el PDF se arma igual

---

### Requirement: Sanear el texto del PDF a Latin-1
<!-- id: pdf_faltantes.latin1Pdf -->
<!-- entities: Reposicion -->
<!-- enforced: pdf_faltantes.latin1Pdf() -->

Todo texto variable del PDF (título, sucursal, aplique, color) DEBE pasar por un saneo que deja los caracteres Latin-1 (tildes y ñ incluidas) y cambia el resto: guiones largos "–" y "—" por "-", comillas tipográficas simples por "'" y dobles por "\"", "…" por "...", y cualquier otro carácter fuera de Latin-1 (p. ej. un emoji) por "?".

#### Scenario: Caracteres especiales
<!-- test: test/features/apliques/domain/pdf_faltantes_test.dart::latin1Pdf: deja tildes y ñ, cambia lo que Helvetica no dibuja -->
- **WHEN** un nombre es "Moño – “rojo” 🎀"
- **THEN** en el PDF se escribe "Moño - \"rojo\" ?"

---

### Requirement: Copiar la lista de faltantes como texto
<!-- id: InventarioScreen._copiar -->
<!-- entities: Reposicion, Sucursal -->
<!-- enforced: InventarioScreen._copiar(), mensaje_faltantes.mensajeFaltantes(), mensaje_faltantes.cantidadLegible() -->

"Copiar lista" DEBE estar habilitado solo si hay faltantes y no está cargando, y DEBE dejar en el portapapeles, en el orden para el fabricante: "*Huantex – Faltantes <sucursal>* (dd/mm/aaaa)", una línea vacía, una línea "• <aplique> – <color>: hacer *N* (quedan S)" por faltante, una línea vacía y "Total a hacer: T"; y avisar "Lista copiada: pegala en WhatsApp".

#### Scenario: Copiar
<!-- test: test/features/apliques/presentation/screens/inventario_screen_test.dart::"Copiar lista" deja el mismo mensaje en el portapapeles -->
- **WHEN** hay faltantes y se toca "Copiar lista"
- **THEN** el portapapeles tiene la lista y se avisa "Lista copiada: pegala en WhatsApp"

#### Scenario: Integración
<!-- test: integration_test/flujos/inventario.dart::un aplique que se vendió y quedó corto aparece en Faltan con cuánto hacer, y la lista copiada lo lleva -->
- **WHEN** un aplique se vendió y quedó corto
- **THEN** aparece en Faltan con cuánto hacer y la lista copiada lo incluye

---

### Invariant: Lo que no se vende no se pide
<!-- entities: Reposicion -->
<!-- enforced: Reposicion.de(), 20261003000100_integridad_stock_y_ventas.sql:inventario_stock_no_negativo -->
<!-- verified_by: integration_test/flujos/inventario.dart::un aplique fabricado sin ventas no está en Faltan pero sí en Todos -->

Un aplique+color sin ventas en la ventana (propias, o de las otras si se estima) NUNCA DEBE ser faltante: su mínimo es 0 y, como el stock nunca es negativo, hacer = 0.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Más stock nunca pide más
<!-- entities: Reposicion -->
<!-- enforced: Reposicion.de() -->
<!-- verified_by: test/propiedades/reposicion_propiedades_test.dart::más stock nunca pide más -->

Con las mismas ventas, aumentar el stock NUNCA DEBE aumentar lo que hay que hacer; hacer es siempre >= 0 y faltante equivale a hacer > 0.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: La consulta del inventario no modifica datos
<!-- entities: StockConVentas -->
<!-- enforced: 20261015000000_inventario_con_ventas.sql:inventario_con_ventas -->
<!-- verified_by: supabase/tests/database/08_inventario_con_ventas.test.sql::inventario_con_ventas es STABLE (solo lee) -->

`inventario_con_ventas` DEBE ser de solo lectura (STABLE) y no decidir nada: la regla de reposición la aplica la app.

> Last verified: 2026-11-06 (commit 1d15233)

<!-- uncertainty: la pantalla toma el nombre de la sucursal de la lista global de sucursales cargada al iniciar; si no está, el título muestra solo "Inventario" y el PDF/texto usan "sucursal <id>" -->
<!-- uncertainty: compartirPdfSistema solo atrapa PlatformException; otra excepción del paquete de compartir no se avisa. Cerrar la hoja de compartir sin elegir destino cuenta como compartido -->
<!-- deferred: lib/features/apliques/domain/entities/stock_aplique.dart, test/features/apliques/presentation/screens/inventario_screen_test.dart (solo nombres de tests) -->
