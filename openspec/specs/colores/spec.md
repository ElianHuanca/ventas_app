---
description: Gestión de colores (listado de activos, alta, modificación y baja lógica) con nombre único y código hex normalizado, validado y previsualizado mientras se escribe.
---

# Spec: colores

> Extraído automáticamente por spec-miner. Última extracción: 2026-11-06.
> Fuente: lib/features/colores/ (colores_datasource.dart, colores_datasource_impl.dart, colores_bloc.dart, color_form_cubit.dart, colores_screen.dart, color_screen.dart), lib/features/apliques/domain/entities/color_item.dart, lib/features/shared/widgets/ (muestra_color.dart, color_from_hex.dart, my_text_form.dart, show_snackbar.dart), lib/features/telas/infrastructure/datasources/telas_datasource_impl.dart (getColoresTela), lib/features/apliques/infrastructure/datasources/apliques_datasource_impl.dart (getColores, getColoresAplique), lib/config/router/app_router.dart, supabase/migrations/20260925000000_prod_schema.sql, supabase/migrations/20261003000100_integridad_stock_y_ventas.sql, supabase/migrations/20261021000000_fotos_de_productos.sql
> Last verified: 2026-11-06 (commit 1d15233)

---

### Requirement: Listar los colores activos
<!-- id: ColoresDatasourceImpl.getColores -->
<!-- entities: ColorItem, colores -->
<!-- enforced: ColoresDatasourceImpl.getColores(), ColoresBloc._onLoadRequested(), ColoresScreen._buildBody(), MuestraColor.build() -->

La pantalla "Colores" (con menú lateral) DEBE listar solo los colores con `activo = true`, ordenados por nombre sin distinguir mayúsculas. Cada fila DEBE mostrar una muestra redonda del color con borde (para que los claros se distingan del fondo), el nombre y el código como "#HEX". Mientras carga DEBE verse un indicador de progreso a pantalla completa; un pedido de recarga mientras ya se está cargando se ignora.

#### Scenario: Colores activos
<!-- test: test/features/colores/presentation/screens/colores_screen_test.dart::lista cada color con su nombre, su hex y la muestra -->
<!-- test: test/features/colores/colores_test.dart::carga la lista de colores -->
<!-- test: test/features/colores/infrastructure/repositories/colores_repository_impl_test.dart::getColores respeta soloActivos (por defecto true) -->
- **WHEN** se abre "Colores"
- **THEN** se ve cada color activo con su muestra, su nombre y "#" seguido de su código

#### Scenario: Sin colores o carga fallida
<!-- test: test/features/colores/presentation/screens/colores_screen_test.dart::sin colores muestra el mensaje de lista vacía -->
- **WHEN** no hay colores activos o la consulta falla
- **THEN** se ve "No hay colores registrados", sin opción de reintentar

#### Scenario: Recarga durante la carga
<!-- test: test/features/colores/colores_test.dart::isLoading queda en true mientras espera al repositorio -->
<!-- test: test/features/colores/colores_test.dart::una recarga pedida mientras carga se ignora -->
- **WHEN** se pide recargar mientras la consulta anterior sigue en curso
- **THEN** no se hace una segunda consulta

#### Scenario: Código guardado inválido
<!-- test: test/features/shared/utils_test.dart::valor inválido devuelve negro opaco -->
<!-- test: test/features/shared/utils_test.dart::hex de largo inválido cae al negro por defecto -->
- **WHEN** un color tiene en la base un código vacío o que no es hexadecimal de 6 u 8 dígitos
- **THEN** su muestra se dibuja negra

<!-- revisar: colores_bloc.dart:57 — una carga fallida (sin conexión) se muestra igual que una lista vacía ("No hay colores registrados"). -->

---

### Requirement: Navegar desde el listado de colores
<!-- id: ColoresScreen.build -->
<!-- entities: ColorItem -->
<!-- enforced: ColoresScreen.build(), ColoresScreen._buildBody() -->

El botón "+" (etiqueta "Agregar color") DEBE abrir el formulario de alta y tocar un color DEBE abrir su formulario de edición; al volver de cualquiera de los dos, la lista DEBE volver a consultarse.

#### Scenario: Agregar
<!-- test: test/features/colores/presentation/screens/colores_screen_test.dart::el botón + navega a /color/0 y recarga al volver -->
- **WHEN** el usuario toca "+" y luego vuelve
- **THEN** se abrió el alta y al volver la lista se recarga

#### Scenario: Editar
<!-- test: test/features/colores/presentation/screens/colores_screen_test.dart::tocar un color navega a /color/:id y recarga al volver -->
- **WHEN** el usuario toca un color y luego vuelve
- **THEN** se abrió la edición de ese color y al volver la lista se recarga

---

### Requirement: Dar de alta un color
<!-- id: ColorFormCubit.onSubmit -->
<!-- entities: ColorItem, colores -->
<!-- enforced: ColorFormCubit.onSubmit(), ColoresBloc.createColor(), ColoresDatasourceImpl.createColor(), 20260925000000_prod_schema.sql:colores_nombre_key -->

El formulario de alta se titula "Crear Color", tiene "Nombre", "Hex (ej: C0392B)" con una vista previa al lado y el botón "Guardar", sin "Eliminar". Con datos válidos DEBE insertar el color con el nombre sin espacios alrededor y el código normalizado (activo por defecto), mostrar "Realizado correctamente" y volver. Si la base lo rechaza (por ejemplo, porque ya existe un color con ese nombre, aunque esté dado de baja) o falla, DEBE mostrar "Hubo un error" y quedarse.

#### Scenario: Formulario vacío
<!-- test: test/features/colores/presentation/screens/color_screen_test.dart::muestra "Crear Color" con "Guardar" y sin "Eliminar" -->
- **WHEN** se abre el alta
- **THEN** se ve "Crear Color" con los campos vacíos y solo "Guardar"

#### Scenario: Guardar un color nuevo
<!-- test: test/features/colores/presentation/screens/color_screen_test.dart::"Guardar" envía el nombre sin espacios y el hex normalizado -->
<!-- test: test/features/colores/colores_test.dart::create envía nombre con trim y hex normalizado -->
<!-- test: integration_test/flujos/colores.dart::crea, renombra y da de baja un color -->
- **WHEN** el usuario escribe " Coral " y "#ff7f50" y toca "Guardar"
- **THEN** queda en la base el color activo "Coral" con código "FF7F50", se ve "Realizado correctamente" y se vuelve

#### Scenario: Nombre repetido
<!-- test: test/features/colores/infrastructure/datasources/colores_datasource_impl_test.dart::nombre repetido > dado de baja: la base rechaza el alta, se ve "Hubo un error" y el formulario sigue abierto -->
<!-- test: test/features/colores/infrastructure/datasources/colores_datasource_impl_test.dart::nombre repetido > activo: la base rechaza el alta y se ve "Hubo un error" -->
- **WHEN** ya existe un color, activo o dado de baja, con el mismo nombre
- **THEN** la base rechaza el alta y se ve "Hubo un error"

#### Scenario: Falla al guardar
<!-- test: test/features/colores/colores_test.dart::createColor con error devuelve false y no toca la lista -->
- **WHEN** el servidor rechaza o no responde el alta
- **THEN** se ve "Hubo un error" y el formulario sigue abierto

<!-- revisar: 20260925000000_prod_schema.sql:532 (colores_nombre_key) — el UNIQUE de nombre incluye los colores dados de baja y la app no permite reactivarlos: un nombre dado de baja no se puede volver a usar y el error no lo explica. -->

---

### Requirement: Normalizar y validar el código hex del color
<!-- id: ColorFormCubit.normalizarHex -->
<!-- entities: ColorItem -->
<!-- enforced: ColorFormCubit.normalizarHex(), ColorFormCubit.onSubmit() -->

El código DEBE aceptarse con o sin "#" y con espacios alrededor, y DEBE tener exactamente 6 dígitos hexadecimales (0-9, a-f, A-F); se guarda sin "#" y en mayúsculas. Cualquier otro valor (vacío, otro largo, con signo "+" o "-", con caracteres no hexadecimales) es inválido. Con el código inválido o el nombre sin espacios vacío, "Guardar" y "Modificar" NO DEBEN enviar nada: DEBEN mostrar "Hubo un error" y quedarse. La base no valida el formato del código.

#### Scenario: Código válido con "#" y minúsculas
<!-- test: test/features/colores/colores_test.dart::acepta 6 dígitos con o sin # y normaliza a mayúsculas sin # -->
- **WHEN** el código escrito es "#c0392b"
- **THEN** se guarda "C0392B"

#### Scenario: Código inválido
<!-- test: test/features/colores/presentation/screens/color_screen_test.dart::no llama al repo, avisa el error y se queda en el formulario -->
<!-- test: test/features/colores/presentation/screens/color_screen_test.dart::hex de largo incorrecto tampoco se envía -->
<!-- test: test/features/colores/colores_test.dart::rechaza largos y caracteres inválidos -->
<!-- test: test/features/colores/colores_test.dart::rechaza signos que int.parse acepta (+00000, -ABCDE) -->
<!-- test: integration_test/flujos/colores.dart::no guarda un color con hex inválido -->
- **WHEN** el código es "XYZ", tiene otro largo o lleva signo, y se toca "Guardar"
- **THEN** no se crea nada, se ve "Hubo un error" y sigue el formulario "Crear Color"

#### Scenario: Nombre vacío
<!-- test: test/features/colores/colores_test.dart::submit con nombre vacío devuelve false sin llamar al repo -->
- **WHEN** el nombre está vacío o tiene solo espacios
- **THEN** no se guarda y se ve "Hubo un error"

---

### Requirement: Previsualizar el color mientras se escribe el código
<!-- id: ColorScreen._form -->
<!-- entities: ColorItem -->
<!-- enforced: ColorScreen._form(), ColorFormCubit.normalizarHex() -->

Al lado del campo del código DEBE haber un círculo que muestra el color cuando el código escrito es válido y queda transparente si no lo es. Con un código no vacío e inválido, el campo DEBE marcar "Hex inválido" mientras se escribe; con el campo vacío no se marca error.

#### Scenario: Código válido
<!-- test: test/features/colores/presentation/screens/color_screen_test.dart::la vista previa toma el color del hex válido -->
- **WHEN** el usuario escribe un código válido
- **THEN** el círculo toma ese color

#### Scenario: Código inválido
<!-- test: test/features/colores/presentation/screens/color_screen_test.dart::el campo marca "Hex inválido" mientras se escribe -->
- **WHEN** el usuario escribe un código no vacío e inválido
- **THEN** el campo muestra "Hex inválido" y el círculo queda transparente

---

### Requirement: Modificar un color
<!-- id: ColorFormCubit.onSubmit -->
<!-- entities: ColorItem, colores -->
<!-- enforced: ColorFormCubit.onSubmit(), ColoresBloc.updateColor(), ColoresDatasourceImpl.updateColor() -->

El formulario de un color existente se titula "Editar Color", precarga nombre y código, y ofrece "Modificar" y "Eliminar". "Modificar" DEBE guardar el nombre sin espacios alrededor y el código normalizado, mostrar "Realizado correctamente" y volver; si falla, "Hubo un error" y se queda.

#### Scenario: Renombrar
<!-- test: test/features/colores/colores_test.dart::update usa el id existente -->
<!-- test: integration_test/flujos/colores.dart::crea, renombra y da de baja un color -->
- **WHEN** el usuario cambia el nombre de un color y toca "Modificar"
- **THEN** el color queda con el nombre nuevo en la base y se vuelve a la lista

#### Scenario: Falla al modificar
<!-- test: test/features/colores/colores_test.dart::updateColor con error devuelve false y no toca la lista -->
- **WHEN** el servidor rechaza o no responde la modificación
- **THEN** se ve "Hubo un error" y el formulario sigue abierto

---

### Requirement: Dar de baja un color sin borrarlo
<!-- id: ColorFormCubit.onDelete -->
<!-- entities: ColorItem, colores -->
<!-- enforced: ColorFormCubit.onDelete(), ColoresBloc.deleteColor(), ColoresDatasourceImpl.deleteColor(), 20261003000100_integridad_stock_y_ventas.sql:REVOKE DELETE ON colores -->

"Eliminar" DEBE marcar el color con `activo = false`, sin borrar la fila y sin pedir confirmación. Si la base confirma que actualizó la fila, el color DEBE salir de la lista, verse "Realizado correctamente" y volver; si no actualizó ninguna fila o falló, DEBE verse "Hubo un error" y quedarse.

#### Scenario: Baja confirmada
<!-- test: test/features/colores/presentation/screens/color_screen_test.dart::"Eliminar" llama a deleteColor con el id y vuelve a la lista -->
<!-- test: test/features/colores/colores_test.dart::deleteColor quita del estado -->
<!-- test: integration_test/flujos/colores.dart::crea, renombra y da de baja un color -->
- **WHEN** el usuario toca "Eliminar" en un color existente
- **THEN** la fila queda con `activo = false`, el color sale de la lista y se vuelve

#### Scenario: Baja no confirmada
<!-- test: test/features/colores/presentation/screens/color_screen_test.dart::si el repo no puede darlo de baja avisa y se queda -->
<!-- test: test/features/colores/colores_test.dart::deleteColor fallido no cambia el estado -->
<!-- test: test/features/colores/colores_test.dart::deleteColor con error del repositorio devuelve false -->
- **WHEN** la base no devuelve la fila actualizada o la operación falla
- **THEN** se ve "Hubo un error" y el color sigue en la lista

---

### Requirement: Mostrar el alta cuando el color a editar no está disponible
<!-- id: ColorScreen.build -->
<!-- entities: ColorItem -->
<!-- enforced: ColorScreen.build() -->

El formulario de edición DEBE buscar el color pedido entre los colores activos recién consultados; mientras consulta muestra un indicador de progreso. Si el color no está (id inexistente, color dado de baja o consulta fallida), DEBE mostrar el formulario de alta vacío ("Crear Color"). Cuando el color aparece, el formulario se recarga con sus datos para que editar no cree un duplicado.

#### Scenario: Color no encontrado
<!-- test: test/features/colores/presentation/screens/color_screen_test.dart::color no encontrado > un id que no está entre los activos muestra "Crear Color" vacío y "Guardar" crea uno nuevo -->
<!-- test: test/features/colores/presentation/screens/color_screen_test.dart::color no encontrado > si la consulta falla también muestra "Crear Color" vacío y "Guardar" crea uno nuevo -->
- **WHEN** se abre la edición de un color que no está entre los activos o la consulta falla
- **THEN** se ve "Crear Color" vacío y "Guardar" crearía un color nuevo

<!-- revisar: color_screen.dart:16-17 — a diferencia de sucursales y telas (pantalla "No se pudo cargar…"), una carga fallida muestra el formulario de alta: el usuario puede crear un color nuevo creyendo que edita uno existente. -->

---

### Invariant: El nombre de un color es único
<!-- entities: colores -->
<!-- enforced: 20260925000000_prod_schema.sql:colores_nombre_key -->

No DEBEN existir dos filas en `colores` con el mismo nombre (incluyendo las dadas de baja); la comparación distingue mayúsculas.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Los colores nunca se borran físicamente
<!-- entities: colores -->
<!-- enforced: 20261003000100_integridad_stock_y_ventas.sql:REVOKE DELETE ON colores -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::DELETE físico solo en ventas y detalle_ventas -->

Ningún usuario de la app DEBE poder borrar filas de `colores`: la baja es siempre `activo = false`.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Solo los colores activos se ofrecen para vincular y se publican
<!-- entities: colores, tela_colores, aplique_colores -->
<!-- enforced: TelasDatasourceImpl.getColoresTela(), ApliquesDatasourceImpl.getColores(), ApliquesDatasourceImpl.getColoresAplique(), 20261021000000_fotos_de_productos.sql:catalogo_telas_web, 20261021000000_fotos_de_productos.sql:catalogo_apliques_web -->
<!-- verified_by: supabase/tests/database/07_vistas_web.test.sql::catalogo_telas_web: también telas sin precio, precio 0 → NULL, solo colores activos con vínculo activo (orden sin mayúsculas), fotos activas por id y foto = la primera -->

Un color con `activo = false` NO DEBE aparecer en las listas para vincular colores a telas o a apliques ni en los colores que publican los catálogos web, aunque conserve vínculos activos.

> Last verified: 2026-11-06 (commit 1d15233)

<!-- uncertainty: la app no ofrece reactivar un color dado de baja; el efecto de dar de baja un color sobre la venta y la fabricación de apliques pertenece a las capacidades apliques/ventas-apliques/fabricacion. -->
