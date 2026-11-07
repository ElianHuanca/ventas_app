# Proyecto: ventas_app

App **Flutter** de punto de venta de telas y apliques para Huantex, sobre Supabase (Postgres).
Es la **referencia de comportamiento** de los ports nativos `ventas_app_android` (Kotlin + Compose)
y `ventas_app_ios` (Swift + SwiftUI), y el **dueño del esquema** de la base que comparten las
tres apps y la landing `sitio`.

- Cómo se trabaja con las specs: `openspec/AGENTS.md`.
- Stack, arquitectura, comandos y convenciones de código: `CLAUDE.md`.
- Lo que cruza repos (decisiones, riesgos abiertos, registro de migraciones, runbooks): vault
  `../notas` (entrada `MAPA.md`).

## Capacidades

Las mismas capacidades, con los mismos nombres de Requirement, están en las tres apps.

| Capacidad | Qué cubre | Flutter | Android | iOS |
|---|---|:-:|:-:|:-:|
| `sesion` | Login con Supabase Auth, sesión persistente, redirección sin sesión, cerrar sesión | ✓ | ✓ | ✓ |
| `sucursales` | Gestión de sucursales y qué telas se venden en cada una | ✓ | ✓ | ✓ |
| `telas` | Catálogo de telas, precios por modalidad y colores de cada tela | ✓ | ✓ | ✓ |
| `colores` | Gestión de colores (nombre + hex) | ✓ | ✓ | ✓ |
| `fotos` | Fotos de telas y apliques en Supabase Storage | ✓ | ✓ | — |
| `dashboard` | Resumen y ranking de ventas de telas y de apliques por período | ✓ | ✓ | ✓ |
| `ventas-telas` | Venta de telas del día: carrito, registro, detalle y borrado de líneas | ✓ | ✓ | ✓ |
| `apliques` | Gestión de apliques y colores de cada aplique | ✓ | ✓ | ✓ |
| `ventas-apliques` | Venta de apliques con stock por color | ✓ | ✓ | ✓ |
| `fabricacion` | Producciones del día que suben el stock | ✓ | ✓ | ✓ |
| `inventario` | Faltantes para el fabricante (regla de reposición, PDF y texto) | ✓ | ✓ | — |
| `contrato-de-datos` | Reglas de la base: RLS, baja lógica, restricciones, idempotencia y vistas públicas | ✓ | — | — |

`contrato-de-datos` existe solo acá porque este repo es dueño del esquema. Los ports describen
las RPC que llaman dentro de la capacidad que las usa.

## La landing `sitio`

`sitio` (Next.js) **también tiene specs** en `../sitio/openspec/`, con las mismas convenciones. No
es un port: es un consumidor de **solo lectura** que no escribe nada y solo consulta las vistas
públicas (`catalogo_telas_web`, `catalogo_apliques_web`, `sucursales_web`), así que no aparece en la
tabla de paridad de arriba.

Reusa cuatro nombres de capacidad —`telas`, `apliques`, `fotos` y `sucursales`— pero **no son las
mismas specs**: acá describen la gestión (alta, edición, precios de compra, stock por color) y allá
solo lo que sale al escaparate. Comparar ambas muestra dónde queda el filtro: `precxcompra`,
`costo_fabricacion`, el stock y los montos vendidos nunca cruzan a la vista pública. Sus otras
capacidades (`pagina`, `catalogo`, `contacto` y `datos`) son propias de la landing.

Un change de acá que **toque una vista pública o una columna que ellas leen** tiene que anotarlo en
el `Impacto` de su `proposal.md` y abrir el change correspondiente en `sitio` con el mismo `<id>`:
la landing no se entera sola de un cambio de esquema. El sentido es siempre este: el change empieza
acá (delta de `contrato-de-datos` + `supabase/landing.sql` reaplicado) y `sitio` lo referencia.

## Paridad (relevada el 2026-11-06: Flutter `1d15233`, Android `4dab27f`, iOS `5dd16c5`)

Cada port marca sus diferencias con Flutter en sus specs con `<!-- paridad: ... -->`, y las resume
en su propio `openspec/project.md`. En pocas palabras:

- **Android** está a la par en reglas de negocio: usa las mismas RPC, incluidas
  `registrar_venta_telas`, `borrar_detalle_venta` y `p_id_operacion`. Difiere en detalles de
  pantalla y le faltan dos cosas menores: la cámara solo en celulares y el saneo Latin-1 del PDF.
  Tiene un bug propio: guarda las fechas elegidas en el calendario sin segundos (`…T00:00`), y como
  `fecha` se compara como texto, el dashboard deja afuera esas ventas cuando el rango empieza ese día.
- **iOS** está detrás:
  - No tiene `fotos` ni `inventario`.
  - La venta de telas encadena `registrar_detalle_venta` + `incrementar_venta`, no
    `registrar_venta_telas`.
  - Ninguna escritura manda `p_id_operacion` y Guardar no se bloquea mientras envía: un reintento
    o un doble toque duplica, y una falla a mitad de camino descuadra el total de la venta.
  - La venta de apliques no tiene listado ni detalle, y la fabricación es de a una línea.
  - El dashboard no usa `top_apliques`.

Por eso `incrementar_venta` y `registrar_detalle_venta` siguen en la base (`contrato-de-datos`):
las usa iOS.

## Comportamientos dudosos

Las specs describen el comportamiento **actual**. Lo que parece un bug está marcado en la spec
con `<!-- revisar: archivo:línea — qué pasa -->`, sin corregir:

```bash
grep -rn "revisar:" openspec/specs
```

Cada uno se resuelve con un change (`openspec/AGENTS.md`). Muchos coinciden con los tests
omitidos (`skip: true`) y los `todo()` de pgTAP, que ya los documentaban.
