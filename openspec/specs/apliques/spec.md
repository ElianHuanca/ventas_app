---
description: Gestión del catálogo de apliques (alta, edición, baja lógica y reactivación; nombre, dimensiones en cm y costo de fabricación), búsqueda en el listado, y vínculo de colores por aplique (aplique_colores) con su efecto en la venta, la fabricación y el inventario.
---

# Spec: apliques

> Extraído automáticamente por spec-miner. Última extracción: 2026-11-06.
> Fuentes: lib/features/apliques/presentation/screens/{apliques,aplique,aplique_colores}_screen.dart, lib/features/apliques/presentation/bloc/{apliques_bloc,aplique_form_cubit,aplique_colores_cubit}.dart, lib/features/apliques/infrastructure/datasources/apliques_datasource_impl.dart, lib/features/apliques/infrastructure/mappers/aplique_mapper.dart, lib/features/shared/widgets/producto_colores_list.dart, supabase/migrations/20260925000000_prod_schema.sql, supabase/migrations/20261003000100_integridad_stock_y_ventas.sql, supabase/migrations/20261007000000_venta_apliques_colores_vinculados.sql
> Last verified: 2026-11-06 (commit 1d15233)

---

### Requirement: Listar los apliques para gestión
<!-- id: ApliquesBloc._onLoadRequested -->
<!-- entities: Aplique -->
<!-- enforced: ApliquesBloc._onLoadRequested(), ApliquesDatasourceImpl.getApliques(), _ApliquesScreenState._apliqueCard() -->

La pantalla de gestión (menú "Apliques") DEBE listar todos los apliques, activos e inactivos, ordenados por nombre sin distinguir mayúsculas. Cada tarjeta DEBE mostrar la parte del nombre anterior a " - " y, como etiquetas, las dimensiones ("A × B cm", con "?" en la que falte, o "Sin dimensiones" si faltan las dos), el costo de fabricación ("C Bs"), la presentación (lo que sigue a " - ", si hay) y "Inactivo" si está dado de baja (nombre atenuado). Mientras carga DEBE mostrar el indicador a pantalla completa. Sin apliques DEBE mostrar "No hay apliques registrados". Si la carga falla la lista queda vacía.

#### Scenario: Activos e inactivos
<!-- test: test/features/apliques/presentation/screens/apliques_screen_test.dart::listado > muestra todos los apliques (también inactivos) -->
- **WHEN** hay apliques activos e inactivos
- **THEN** se ven todos, y los inactivos con la etiqueta "Inactivo"

#### Scenario: Etiquetas de la tarjeta
<!-- test: test/features/apliques/presentation/screens/apliques_screen_test.dart::listado > muestra medidas, costo y la presentación como chips -->
- **WHEN** un aplique se llama "Flor Grande - Bolsa x100 und", mide 4 × 5.5 cm y cuesta 15 Bs
- **THEN** la tarjeta muestra "Flor Grande" y las etiquetas "4.0 × 5.5 cm", "15.0 Bs" y "Bolsa x100 und"

#### Scenario: Sin apliques
<!-- test: test/features/apliques/presentation/screens/apliques_screen_test.dart::listado > sin apliques muestra el mensaje de lista vacía -->
- **WHEN** no hay apliques
- **THEN** se ve "No hay apliques registrados"

---

### Requirement: Buscar apliques por nombre
<!-- id: _ApliquesScreenState._buildBody -->
<!-- entities: Aplique -->
<!-- enforced: _ApliquesScreenState._buildBody() -->

El campo "Buscar aplique..." DEBE filtrar al tipear los apliques cuyo nombre completo (incluida la presentación) contiene el texto, sin distinguir mayúsculas. Sin coincidencias DEBE mostrar "Sin resultados para esa búsqueda". Al volver de editar, el texto y el filtro DEBEN seguir coherentes.

#### Scenario: Filtro sin mayúsculas
<!-- test: test/features/apliques/presentation/screens/apliques_screen_test.dart::búsqueda > filtra por nombre sin distinguir mayúsculas -->
- **WHEN** se escribe "flor" y existe "Flor Grande"
- **THEN** aparece "Flor Grande" y no los que no lo contienen

#### Scenario: Sin coincidencias
<!-- test: test/features/apliques/presentation/screens/apliques_screen_test.dart::búsqueda > sin coincidencias avisa que no hay resultados -->
- **WHEN** ningún nombre contiene el texto
- **THEN** se ve "Sin resultados para esa búsqueda"

---

### Requirement: Navegar desde el listado de apliques
<!-- id: _ApliquesScreenState._apliqueCard -->
<!-- entities: Aplique -->
<!-- enforced: _ApliquesScreenState.build(), _ApliquesScreenState._apliqueCard() -->

El botón "+" ("Agregar aplique") DEBE abrir el formulario de alta; tocar la tarjeta o "Modificar" DEBE abrir la edición de ese aplique; en los tres casos la lista DEBE recargarse al volver. "Colores" DEBE abrir los colores del aplique y "Fotos" sus fotos, sin recargar al volver.

#### Scenario: Alta
<!-- test: test/features/apliques/presentation/screens/apliques_screen_test.dart::navegación > el botón + navega a /aplique/0 y recarga al volver -->
- **WHEN** el usuario toca "+" y vuelve
- **THEN** se abrió el formulario vacío y la lista se recarga

#### Scenario: Colores
<!-- test: test/features/apliques/presentation/screens/apliques_screen_test.dart::navegación > "Colores" navega a /aplique-colores/:id sin recargar al volver -->
- **WHEN** el usuario toca "Colores" en una tarjeta
- **THEN** se abren los colores de ese aplique

---

### Requirement: Validar los datos del aplique antes de guardar
<!-- id: ApliqueFormCubit.onSubmit -->
<!-- entities: Aplique -->
<!-- enforced: ApliqueFormCubit.onSubmit(), ApliqueFormCubit._esMedidaValida() -->

Guardar NO DEBE enviar nada y DEBE avisar "Hubo un error" si el nombre está vacío o solo tiene espacios, si el costo de fabricación está vacío, no es numérico o es negativo, o si el ancho o el alto no están vacíos y no son números mayores a 0. Las medidas son opcionales.

#### Scenario: Costo vacío
<!-- test: test/features/apliques/presentation/screens/aplique_screen_test.dart::validaciones (no llaman al repo) > costo vacío -->
- **WHEN** se guarda con el costo vacío
- **THEN** se avisa "Hubo un error" y no se crea nada

#### Scenario: Medida en 0
<!-- test: test/features/apliques/presentation/screens/aplique_screen_test.dart::validaciones (no llaman al repo) > medida en 0 -->
- **WHEN** el ancho o el alto valen 0, son negativos o no son números
- **THEN** se avisa "Hubo un error" y no se guarda

#### Scenario: Nombre en blanco
<!-- test: test/features/apliques/presentation/bloc/aplique_form_cubit_test.dart::onSubmit validaciones > nombre vacío o solo espacios devuelve false -->
- **WHEN** el nombre solo tiene espacios
- **THEN** no se guarda

---

### Requirement: Dar de alta un aplique
<!-- id: ApliquesBloc.createAplique -->
<!-- entities: Aplique -->
<!-- depends_on: Validar los datos del aplique antes de guardar -->
<!-- enforced: ApliqueScreen._form(), ApliqueFormCubit.onSubmit(), ApliquesBloc.createAplique(), ApliquesDatasourceImpl.createAplique() -->

El formulario de alta ("Crear Aplique") DEBE pedir Nombre, Ancho (cm), Alto (cm) y Costo de fabricación, sin interruptor "Activo". "Guardar" DEBE crear el aplique con el nombre sin espacios al borde, las medidas como número o NULL si quedaron vacías, el costo como número y activo. Con éxito DEBE avisar "Realizado correctamente" y volver al listado; si la base falla DEBE avisar "Hubo un error" y quedarse en el formulario.

#### Scenario: Alta completa
<!-- test: integration_test/flujos/apliques.dart::crea un aplique, lo modifica y lo desactiva -->
- **WHEN** se completan nombre, medidas y costo y se toca "Guardar"
- **THEN** se crea el aplique activo con esos datos y se vuelve al listado

#### Scenario: Medidas vacías
<!-- test: test/features/apliques/presentation/screens/aplique_screen_test.dart::crear > las medidas son opcionales: vacías se envían como null -->
- **WHEN** se deja vacío el ancho y el alto
- **THEN** se guardan como NULL

#### Scenario: Falla la base
<!-- test: test/features/apliques/presentation/screens/aplique_screen_test.dart::crear > un error del repo avisa y se queda en el formulario -->
- **WHEN** la base rechaza el alta
- **THEN** se avisa "Hubo un error" y el formulario sigue abierto

---

### Requirement: Editar un aplique
<!-- id: ApliquesBloc.updateAplique -->
<!-- entities: Aplique -->
<!-- depends_on: Validar los datos del aplique antes de guardar -->
<!-- enforced: ApliqueScreen.build(), ApliqueFormCubit.onSubmit(), ApliquesBloc.updateAplique(), ApliquesDatasourceImpl.updateAplique() -->

El formulario de edición ("Editar Aplique") DEBE precargar nombre, medidas (vacías si son NULL), costo (vacío si es 0) y el interruptor "Activo"; "Modificar" DEBE actualizar el aplique con los mismos criterios que el alta. Con éxito avisa "Realizado correctamente" y vuelve; con error avisa "Hubo un error". Mientras se carga el listado DEBE mostrar el indicador; si el id no está entre los apliques cargados (o es 0) DEBE mostrar el formulario de alta.

#### Scenario: Precarga
<!-- test: test/features/apliques/presentation/bloc/aplique_form_cubit_test.dart::estado inicial > aplique existente precarga los campos -->
- **WHEN** se abre la edición de un aplique de 4 × 5.5 cm y costo 15
- **THEN** los campos muestran "4.0", "5.5" y "15.0"

#### Scenario: Costo en cero
<!-- test: test/features/apliques/presentation/bloc/aplique_form_cubit_test.dart::estado inicial > aplique nuevo: costo 0 y medidas se muestran vacíos -->
- **WHEN** el aplique tiene costo de fabricación 0
- **THEN** el campo de costo aparece vacío y hay que volver a escribir el costo para poder guardar

<!-- revisar: aplique_form_cubit.dart:52-54 precarga vacío un costo 0 y aplique_form_cubit.dart:60-61 rechaza el costo vacío: modificar (o dar de baja) un aplique con costo 0 falla con "Hubo un error" hasta tipear 0 -->
<!-- revisar: aplique_screen.dart:16-19 con un id que no está en la lista (o si falló la carga) muestra "Crear Aplique" y "Guardar" crea uno nuevo -->

---

### Requirement: Dar de baja o reactivar un aplique
<!-- id: ApliqueFormCubit.onActivoChanged -->
<!-- entities: Aplique -->
<!-- enforced: ApliqueScreen._form(), ApliqueFormCubit.onActivoChanged(), ApliquesBloc.updateAplique() -->

En la edición, apagar "Activo" ("Los apliques inactivos no se ofrecen en las ventas") y tocar "Modificar" DEBE dar de baja el aplique con `activo = false` (nunca se borra); encenderlo DEBE reactivarlo. Un aplique inactivo NO DEBE ofrecerse en la venta de apliques ni en Fabricación, NO DEBE aparecer en el Inventario ni en el catálogo web, y DEBE seguir en el listado de gestión.

#### Scenario: Dar de baja
<!-- test: test/features/apliques/presentation/screens/aplique_screen_test.dart::switch Activo (edición) > apagarlo y "Modificar" da de baja el aplique -->
- **WHEN** se apaga "Activo" y se toca "Modificar"
- **THEN** el aplique queda con activo = false

#### Scenario: Reactivar
<!-- test: test/features/apliques/presentation/screens/aplique_screen_test.dart::switch Activo (edición) > un aplique inactivo precarga apagado y se puede reactivar -->
- **WHEN** se abre un aplique inactivo, se enciende "Activo" y se modifica
- **THEN** el aplique vuelve a estar activo

#### Scenario: Inactivo fuera de la venta
<!-- test: test/features/apliques/presentation/bloc/apliques_bloc_test.dart::modo venta (con idsucursal) > carga solo activos y el stock de la sucursal -->
- **WHEN** un aplique está inactivo
- **THEN** el selector de la venta de apliques no lo ofrece

---

### Requirement: Listar los colores del aplique con su vínculo
<!-- id: ApliquesDatasourceImpl.getColoresAplique -->
<!-- entities: ColorItem, ApliqueColor, Aplique -->
<!-- enforced: ApliqueColoresCubit.load(), ApliquesDatasourceImpl.getColoresAplique(), ApliqueColoresScreen.build() -->

La pantalla de colores del aplique DEBE listar todos los colores activos, ordenados por nombre sin distinguir mayúsculas, cada uno con su muestra y un interruptor encendido si el color tiene vínculo activo con el aplique. El título DEBE ser la parte del nombre del aplique anterior a " - ", o "Colores del aplique" si no se conoce. Mientras carga DEBE mostrar un indicador.

#### Scenario: Orden y estado
<!-- test: test/features/apliques/presentation/screens/aplique_colores_screen_test.dart::muestra un switch por color, ordenados sin distinguir mayúsculas -->
- **WHEN** se abre la pantalla de colores de un aplique
- **THEN** se ve un interruptor por color activo, en orden alfabético, encendido en los vinculados

#### Scenario: Título
<!-- test: test/features/apliques/presentation/screens/aplique_colores_screen_test.dart::el título es el nombre del aplique sin la presentación -->
- **WHEN** el aplique se llama "Flor Grande - Bolsa x100 und"
- **THEN** el título es "Flor Grande"

---

### Requirement: Vincular o desvincular un color del aplique
<!-- id: ApliqueColoresCubit.toggleColor -->
<!-- entities: ApliqueColor -->
<!-- enforced: ApliqueColoresCubit.toggleColor(), ApliquesDatasourceImpl.setColorAplique() -->

Cambiar el interruptor DEBE guardar el vínculo (aplique, color) con `activo` igual al nuevo valor (lo crea si no existía; desvincular es baja lógica, nunca DELETE) y, si se guardó, reflejarlo. Si la base falla el interruptor DEBE quedar como estaba, sin aviso.

#### Scenario: Vincular
<!-- test: test/features/apliques/presentation/screens/aplique_colores_screen_test.dart::encender un color lo vincula con setColorAplique -->
- **WHEN** se enciende un color
- **THEN** queda el vínculo activo

#### Scenario: Desvincular
<!-- test: test/features/apliques/presentation/screens/aplique_colores_screen_test.dart::apagar un color lo desvincula (baja lógica) -->
- **WHEN** se apaga un color
- **THEN** el vínculo queda con activo = false

#### Scenario: Falla
<!-- test: test/features/apliques/presentation/screens/aplique_colores_screen_test.dart::si el repo falla, el switch queda como estaba -->
- **WHEN** la base rechaza el cambio
- **THEN** el interruptor vuelve a su valor anterior

---

### Requirement: Usar solo colores vinculados en venta, fabricación e inventario
<!-- id: ApliquesDatasourceImpl.soloColoresVinculados -->
<!-- entities: ApliqueColor, Inventario, ColorItem -->
<!-- enforced: ApliquesDatasourceImpl.soloColoresVinculados(), ApliquesDatasourceImpl.getStock(), ProduccionFormCubit.onApliqueChanged(), 20261020000000_idempotencia_y_venta_telas.sql:crear_venta_apliques, 20261015000000_inventario_con_ventas.sql:inventario_con_ventas -->

Un color sin vínculo activo con el aplique NO DEBE ofrecerse para ese aplique en la venta de apliques (aunque tenga stock), ni en Fabricación, ni aparecer en el Inventario; la base DEBE rechazar una venta que lo traiga. El vínculo es por aplique: el vínculo de un color con otro aplique no cuenta. Habilitar un color DEBE ofrecerlo en Fabricación (en la venta aparece cuando la sucursal tiene inventario de ese aplique+color).

#### Scenario: Deshabilitar un color
<!-- test: integration_test/flujos/apliques.dart::deshabilitar un color del aplique lo saca de Fabricación y de la venta -->
- **WHEN** se desvincula un color que tiene stock en una sucursal
- **THEN** deja de ofrecerse en Fabricación y en la venta de esa sucursal

#### Scenario: Habilitar un color
<!-- test: integration_test/flujos/apliques.dart::habilitar un color desde la UI lo ofrece en Fabricación -->
- **WHEN** se vincula un color
- **THEN** Fabricación lo ofrece para ese aplique

#### Scenario: Vínculo de otro aplique
<!-- test: test/features/apliques/infrastructure/datasources/stock_colores_vinculados_test.dart::el vínculo es por aplique: el color de otro aplique no cuenta -->
- **WHEN** un color está vinculado a otro aplique pero no a este
- **THEN** no se ofrece para este aplique

---

### Invariant: Costo de fabricación no negativo
<!-- entities: Aplique -->
<!-- enforced: ApliqueFormCubit.onSubmit(), 20261003000100_integridad_stock_y_ventas.sql:apliques_costo_no_negativo -->
<!-- verified_by: supabase/tests/database/05_restricciones.test.sql::apliques: no acepta costo de fabricación negativo -->

Todo aplique DEBE tener nombre (NOT NULL) y costo de fabricación >= 0 (default 0).

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Dimensiones en centímetros con hasta dos decimales
<!-- entities: Aplique -->
<!-- enforced: 20260925000000_prod_schema.sql:apliques.ancho_cm, 20260925000000_prod_schema.sql:apliques.alto_cm, ApliqueFormCubit._esMedidaValida() -->

`ancho_cm` y `alto_cm` DEBEN ser NULL o `numeric(5,2)` (menos de 1000 cm, redondeado a 2 decimales por la base); la app solo acepta medidas vacías o mayores a 0.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Un vínculo por aplique y color
<!-- entities: ApliqueColor -->
<!-- enforced: 20260925000000_prod_schema.sql:aplique_colores_pkey -->
<!-- verified_by: supabase/tests/database/05_restricciones.test.sql::aplique_colores: un vínculo por aplique+color -->

`aplique_colores` NO DEBE tener dos filas del mismo aplique y color; el estado del vínculo es su columna `activo`.

> Last verified: 2026-11-06 (commit 1d15233)

---

### Invariant: Los apliques y sus vínculos nunca se borran físicamente
<!-- entities: Aplique, ApliqueColor -->
<!-- enforced: 20261003000100_integridad_stock_y_ventas.sql:REVOKE DELETE -->
<!-- verified_by: supabase/tests/database/01_rls_y_permisos.test.sql::DELETE físico solo en ventas y detalle_ventas -->

Ni la app ni ningún usuario de la API DEBEN poder borrar filas de `apliques` ni de `aplique_colores`: la baja es `activo = false`.

> Last verified: 2026-11-06 (commit 1d15233)

<!-- uncertainty: la columna apliques.tamanio se lee (ApliqueMapper) y la publica catalogo_apliques_web, pero ningún formulario la escribe -->
<!-- uncertainty: los cambios de interruptor en colores no tienen control de concurrencia ni confirmación; el último en guardar gana (upsert) -->
<!-- deferred: lib/features/apliques/domain/entities/color_item.dart, lib/features/apliques/infrastructure/repositories/apliques_repository_impl.dart, lib/features/shared/widgets/muestra_color.dart, lib/features/shared/widgets/my_text_form.dart -->

---

### Invariant: Categoría y nombre saneados por la base
<!-- id: apliques.saneamiento_catalogo -->
<!-- entities: Aplique, apliques, categorias -->
<!-- enforced: supabase/migrations/20261110000000_saneamiento_catalogo.sql:normalizar_nombre, DEFAULT apliques.categoria_id -->

Todo aplique DEBE quedar con `categoria_id` = "Apliques" aunque la app no lo mande (DEFAULT 2), y su `nombre`
DEBE guardarse recortado, sin espacios dobles y con mayúscula inicial (disparador `normalizar_nombre`). El
costo de fabricación sigue siendo responsabilidad del dueño (hoy 14 apliques en 0; ver specs/001-saneamiento-catalogo).

#### Scenario: Alta sin categoría
<!-- test: supabase/tests/database/11_saneamiento_catalogo.test.sql::aplique nuevo queda en la categoría Apliques -->
- **WHEN** se inserta un aplique " mariposa prueba" sin `categoria_id`
- **THEN** queda "Mariposa prueba" con `categoria_id = 2`
