# Feature Specification: Saneamiento del catálogo

**Feature Branch**: `feat/saneamiento-catalogo`

**Created**: 2026-11-10

**Status**: Aprobado (2026-11-10, dueño: "procede por ambas")

**Input**: Hallazgos del informe de calidad de `huantex_datos` (2026-11-09): las 30 telas y 2 apliques no
tienen categoría; 3 nombres de telas con espacios al borde o inicial en minúscula ("tull Escarchado ",
"Tull Maripozas ", "lipiur AG"); los 14 apliques tienen costo de fabricación 0.

## Clarifications

### Session 2026-11-10

- Q: ¿Por qué faltan las categorías? → A: Ninguna pantalla de la app (ni los ports) manda `categoria_id`
  al crear telas o apliques; la columna quedó siempre nula. La corrección va en la **base**: categoría por
  defecto (telas → "Telas", apliques → "Apliques") más relleno de las filas existentes. Aditiva: las apps
  viejas siguen funcionando y, sin cambiar, empiezan a dejar la categoría puesta.
- Q: ¿Los nombres se corrigen en la app o en la base? → A: En la **base**, con un disparador al insertar o
  modificar el nombre de telas, apliques y colores: recorta espacios al borde, colapsa espacios dobles y
  pone la primera letra en mayúscula. Así vale para Flutter, Android, iOS y la landing sin tocar código.
  El resto del nombre no se toca ("Tull Maripozas" conserva su ortografía; si es un error, lo corrige el
  dueño en la app).
- Q: ¿Y los costos de fabricación en 0? → A: Son **datos del negocio que solo el dueño conoce**; no se
  inventan ni se obligan por base (un CHECK `> 0` rompería el alta actual). Quedan como tarea manual en la
  app (pantalla Apliques → editar → costo). Esta feature los lista.
- Q: ¿Cómo se prueba? → A: Test pgTAP nuevo (`11_saneamiento_catalogo.test.sql`) para `npx supabase test db`
  y, antes de aplicar a producción, la migración se corre sobre la copia local `huantex_dw` (volcado exacto
  de producción del 2026-11-09) comprobando los conteos.

## User Scenarios & Testing

### User Story 1 - Categoría siempre puesta (Priority: P1)
1. **Given** la migración aplicada, **When** se crea una tela desde cualquier app sin indicar categoría,
   **Then** queda con la categoría "Telas"; un aplique nuevo queda con "Apliques".
2. **Given** las telas y apliques existentes sin categoría, **When** se aplica la migración, **Then** todas
   quedan con su categoría y el informe de calidad deja de marcar `producto_sin_categoria`.

### User Story 2 - Nombres limpios (Priority: P2)
1. **Given** la migración aplicada, **When** se guarda una tela, aplique o color con nombre " tull  escarchado ",
   **Then** se almacena "Tull escarchado".
2. **Given** los tres nombres mal escritos, **When** se aplica la migración, **Then** quedan "Tull Escarchado",
   "Tull Maripozas" y "Lipiur AG", y `producto_nombre_mal_escrito` da 0.
3. **Given** un nombre que ya está limpio, **When** se guarda, **Then** no cambia.

### User Story 3 - Costos pendientes a la vista (Priority: P3)
1. **Given** esta spec, **When** el dueño la lee, **Then** encuentra la lista de los 14 apliques a los que
   debe cargar costo de fabricación en la app.

### Edge Cases
- Nombre que al normalizarse colisiona con un UNIQUE (`colores.nombre`): hoy no hay colisiones (verificado);
  si ocurriera, la base rechaza el cambio con el error de unicidad habitual.
- Nombre vacío o solo espacios: el disparador lo deja vacío y la validación de la app sigue siendo la que
  impide guardarlo.

## Requirements
- **FR-001**: Migración `supabase/migrations/20261110000000_saneamiento_catalogo.sql`, aditiva e idempotente:
  `DEFAULT` de `categoria_id` (telas → 1, apliques → 2), relleno de nulos, función `normalizar_nombre()` +
  disparadores `BEFORE INSERT OR UPDATE OF nombre` en `telas`, `apliques`, `colores`, y relleno de los
  nombres existentes.
- **FR-002**: Test pgTAP que cubra defaults, disparador (insert y update), idempotencia del relleno.
- **FR-003**: Catálogo `openspec/specs/{telas,apliques,colores}/spec.md` con el Invariant nuevo y su `enforced`.
- **FR-004**: Fila en `notas/datos/migraciones/registro-de-migraciones.md` antes de aplicar.
- **FR-005**: La aplicación a producción la hace el dueño (Studio o pooler), con prechequeo y verificación
  escritos en `supabase/aplicar_en_produccion_20261110.md`.

## Non-Goals
- NO se agrega campo de categoría a los formularios (la categoría es una por tipo; no aporta elegirla).
- NO se obliga `costo_fabricacion > 0` por base; NO se corrige ortografía más allá de espacios y mayúscula inicial.

## Success Criteria
- **SC-001**: Tras aplicar en la copia local: 0 telas y 0 apliques con `categoria_id` nulo; 0 nombres con
  espacios al borde o inicial en minúscula en telas, apliques y colores; conteos de filas sin cambios.
- **SC-002**: Correr la migración dos veces deja el mismo resultado (idempotente).
- **SC-003**: `huantex calidad` (repo huantex_datos) sobre un respaldo posterior reporta 0 en
  `producto_sin_categoria` y `producto_nombre_mal_escrito`.

## Costos de fabricación pendientes (US3)
Flor Petalo Suizo Grande; Flor Petalo Razo Grande; Flor Petalo Suizo Pequeno; Flor Petalo Brilloso Pequeno;
Mariposa Razo Mediano; Mariposa Suizo Mediano; Mariposa Razo Grande; Mariposa Razo Chico; Mariposa Razo Extra
Chico; Flor Petalo Brilloso Grande; Mariposa Brilloso Extra Chico; Mariposa Razo C/Brillo Mediano; Mariposa
Brilloso Mediano; Mariposa D2 C/Brillo Pequeño (todos "Bolsa x100 und" salvo el último).