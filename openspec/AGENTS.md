# Spec-driven development (OpenSpec)

Las specs de `openspec/specs/` describen **lo que la app hace hoy**. Son la fuente de verdad del
comportamiento: si el código y la spec no coinciden, uno de los dos tiene un bug. Ningún cambio de
comportamiento entra sin pasar primero por una spec.

## Estructura

```
openspec/
  project.md                      contexto: la app, las capacidades y la paridad entre las tres apps
  AGENTS.md                       este archivo: cómo se trabaja
  specs/<capacidad>/spec.md       comportamiento vigente (una carpeta por capacidad)
  changes/<id>/                   cambios en curso
    proposal.md                   por qué y qué cambia
    tasks.md                      checklist de implementación
    design.md                     (opcional) decisiones técnicas, si el cambio las tiene
    specs/<capacidad>/spec.md     delta: cómo queda la spec de cada capacidad afectada
  changes/archive/AAAA-MM-DD-<id>/  cambios ya aplicados (historia)
```

## ¿Hace falta un change?

| Sí: abrir `changes/<id>/` | No: directo al código |
|---|---|
| Feature nueva o pantalla nueva | Refactor sin cambio de comportamiento |
| Cambio de una regla, cálculo, validación o mensaje que ve el usuario | Tests nuevos para comportamiento que ya está en la spec |
| RPC, tabla, columna o política nueva o cambiada | Lints, formato, nombres internos |
| Quitar un flujo | Dependencias sin efecto observable |
| Resolver un `<!-- revisar: -->` cambiando el comportamiento | Arreglar código que **no cumple** su spec (la spec ya dice lo correcto: agregar el test que falta) |

Ante la duda, sí.

## Flujo

1. **Proponer.** Crear `openspec/changes/<id>/`, con `<id>` en kebab-case y empezando con un verbo
   (`agregar-devoluciones`, `cambiar-regla-de-reposicion`, `quitar-incrementar-venta`).
   - `proposal.md`: **Por qué**, **Qué cambia**, **Capacidades afectadas** y **Impacto**: otras
     apps, base de datos, datos de producción, landing (`sitio`).
   - `specs/<capacidad>/spec.md`: el delta (formato abajo). Cada Requirement nuevo o modificado
     lleva al menos un `#### Scenario:`.
   - `tasks.md`: checklist ordenado (`- [ ] 1.1 ...`), con los tests primero.
2. **Aprobar.** Mostrar la propuesta y **esperar el OK antes de tocar código**.
3. **Implementar.** Seguir `tasks.md`, marcando cada tarea. Cada `Scenario` del delta se convierte
   en al menos un test que primero falla y después pasa. Si al implementar aparece algo que la
   propuesta no previó, se corrige primero el delta.
4. **Verificar.** Ver "Verificar en este repo" abajo.
5. **Archivar.** Aplicar el delta a `openspec/specs/`, actualizar el `Last verified` de cada spec
   tocada y mover la carpeta a `changes/archive/AAAA-MM-DD-<id>/`. Va en el **mismo PR** que el
   código: una spec archivada siempre describe código mergeado.

## Formato del delta

```markdown
## ADDED Requirements

### Requirement: <nombre nuevo>
<!-- enforced: ... -->
La app DEBE ...

#### Scenario: <nombre>
- **WHEN** ...
- **THEN** ...

## MODIFIED Requirements

### Requirement: <nombre exacto como está hoy en specs/>
(el bloque completo como tiene que quedar, con todos sus escenarios, no solo lo que cambia)

## REMOVED Requirements

### Requirement: <nombre exacto>
**Motivo**: ...

## RENAMED Requirements

- FROM: `### Requirement: <nombre viejo>`
- TO: `### Requirement: <nombre nuevo>`
```

Lo mismo con `Invariant`. Al archivar: ADDED se agrega, MODIFIED reemplaza el bloque entero,
REMOVED se borra y RENAMED cambia solo el título. El `<!-- id: -->` no cambia al renombrar.

## Cómo están escritas las specs

- **Español**, con los marcadores de OpenSpec en inglés (`### Requirement:`, `### Invariant:`,
  `#### Scenario:`, `- **WHEN**`, `- **THEN**`). El verbo normativo es **DEBE / NO DEBE**.
- **Requirement** es algo que pasa cuando ocurre algo (WHEN → THEN). **Invariant** es algo que se
  cumple siempre (por ejemplo el stock nunca es negativo).
- **Nombres neutrales de plataforma**: describen lo que ve el usuario o lo que queda en la base,
  nunca la implementación. Por eso **los mismos nombres de Requirement se usan en `ventas_app`
  (Flutter), `ventas_app_android` y `ventas_app_ios`**: comparar las specs de las tres apps
  muestra la paridad.
- La metadata va en comentarios HTML:
  - `id`: punto de anclaje estable, `Archivo.metodo`.
  - `entities`: las entidades que intervienen.
  - `enforced`: dónde se hace cumplir, en la app o en la base (`migracion.sql:funcion`).
  - `test` / `verified_by`: el test que lo cubre.
  - `depends_on` / `triggers`: relaciones con otros requisitos de la misma capacidad.
  Al mover o renombrar un método, actualizar su `enforced`.
- `<!-- revisar: ... -->` marca un comportamiento actual que parece un bug. La spec describe lo
  que hace el código **hoy**: para cambiarlo, abrir un change.
- `<!-- deferred: ... -->` marca archivos que no se leyeron al extraer la spec. Se completan
  cuando se toca esa capacidad.

## Tres apps, una base

- Las tres apps comparten la base Supabase. **`ventas_app` (Flutter) es el dueño del esquema y la
  referencia de comportamiento.** Su capacidad `contrato-de-datos` describe las reglas de la base
  (RLS, baja lógica, restricciones, idempotencia y vistas públicas).
- Un cambio de comportamiento compartido se propone con **el mismo `<id>`** en cada app afectada.
  Si toca la base, empieza en `ventas_app` (delta de `contrato-de-datos` y de la capacidad) y los
  ports referencian ese change en su `proposal.md`.
- Los cambios de esquema siguen además el runbook del vault:
  `../notas/runbooks/cambiar-el-esquema.md`. El conocimiento que cruza repos (decisiones, riesgos,
  registro de migraciones) sigue viviendo en `../notas`: las specs no lo duplican, lo enlazan.
- Las diferencias conocidas entre las tres apps están en `openspec/project.md` → "Paridad".

## Herramienta

No hace falta ninguna: son archivos Markdown. Si se instala el CLI de OpenSpec
(`npm i -g @fission-ai/openspec`), `openspec list` y `openspec show <capacidad>` sirven para
navegar. El validador estricto espera SHALL/MUST en inglés y estas specs usan DEBE.

## Verificar en este repo

```bash
flutter analyze                       # tiene que quedar limpio
flutter test                          # unitarios, de widget y capturas (sin omitidos nuevos)
npx supabase@latest db reset          # si el change trae migración (Supabase local)
npx supabase@latest test db           # pgTAP: RLS, RPC, restricciones y 09_contrato
```

Si el change cambia un flujo completo, sumar o ajustar su test en `integration_test/flujos/` y
correr la integración contra el Supabase local (comandos y cuelgues conocidos en `CLAUDE.md` →
"Integración").

Un `Scenario` sin test es una tarea pendiente. Los tests omitidos (`skip: true`) son bugs
conocidos (ver `CLAUDE.md` → "Tests"): si un change los arregla, se quita el `skip`.
