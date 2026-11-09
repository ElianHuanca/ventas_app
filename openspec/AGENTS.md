# El catálogo de specs (`openspec/specs`)

Las specs de `openspec/specs/` describen **lo que la app hace hoy**. Son el catálogo del
comportamiento vigente: si el código y la spec no coinciden, uno de los dos tiene un bug. Ningún
cambio de comportamiento entra sin pasar primero por una spec.

**El proceso para cambiar algo es Spec Kit** (`/speckit-*`, ver `CLAUDE.md` → "Spec-driven
development"), con las reglas de `.specify/memory/constitution.md`. Este archivo explica cómo está
escrito el catálogo y cómo lo actualiza cada feature. Ya no se abren changes en
`openspec/changes/`: lo archivado ahí es historia.

## Estructura

```
openspec/
  project.md                      contexto: la app, las capacidades y la paridad entre las tres apps
  AGENTS.md                       este archivo: cómo se trabaja
  specs/<capacidad>/spec.md       comportamiento vigente (una carpeta por capacidad)
  changes/archive/AAAA-MM-DD-<id>/  cambios aplicados antes de pasar a Spec Kit (historia)

specs/NNN-<nombre>/               (raíz del repo) cada feature de Spec Kit: spec, plan y tareas
.specify/memory/constitution.md   las reglas que no se negocian
```

## ¿Hace falta una feature de Spec Kit?

| Sí: `/speckit-specify` y el resto del flujo | No: directo al código |
|---|---|
| Feature nueva o pantalla nueva | Refactor sin cambio de comportamiento |
| Cambio de una regla, cálculo, validación o mensaje que ve el usuario | Tests nuevos para comportamiento que ya está en la spec |
| RPC, tabla, columna o política nueva o cambiada | Lints, formato, nombres internos |
| Quitar un flujo | Dependencias sin efecto observable |
| Resolver un `<!-- revisar: -->` cambiando el comportamiento | Arreglar código que **no cumple** su spec (la spec ya dice lo correcto: agregar el test que falta) |

Ante la duda, sí.

## Flujo (Spec Kit)

1. **`/speckit-specify`** con qué se quiere y por qué. La spec de la feature tiene que nombrar las
   capacidades del catálogo que toca y el **impacto** en Android, iOS, la base, los datos de
   producción y la landing (`sitio`).
2. **`/speckit-clarify`** (obligatorio): resuelve ambigüedades. Las decisiones de negocio las toma
   la persona, no la IA.
3. **`/speckit-plan`**: el cómo técnico. Tiene que pasar el "Constitution Check".
4. **`/speckit-tasks`**: tareas ordenadas, con los tests primero e incluida **la actualización del
   catálogo** (`openspec/specs/`).
5. **`/speckit-analyze`** (obligatorio): revisión cruzada de spec, plan, tareas y constitución.
6. **`/speckit-implement`**: cada escenario se vuelve al menos un test que primero falla y después
   pasa. Si aparece algo que la spec no previó, primero se corrige la spec.
7. **Verificar** (abajo) y **`/speckit-converge`**: compara el código con la spec y agrega como
   tareas lo que falte.
8. **Actualizar el catálogo** en el mismo PR que el código: en `openspec/specs/<capacidad>/spec.md`
   se agregan, modifican, renombran o quitan los `Requirement` / `Invariant` (con sus escenarios
   completos) y se actualiza el `Last verified`. El `<!-- id: -->` no cambia al renombrar. Una spec
   del catálogo siempre describe código mergeado.

Si el negocio cambia sobre algo ya hecho: `/speckit-clarify <qué cambia>` y se repite desde el
paso 3.

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
  que hace el código **hoy**: para cambiarlo, hace falta una feature de Spec Kit.
- `<!-- deferred: ... -->` marca archivos que no se leyeron al extraer la spec. Se completan
  cuando se toca esa capacidad.

## Tres apps, una base

- Las tres apps comparten la base Supabase. **`ventas_app` (Flutter) es el dueño del esquema y la
  referencia de comportamiento.** Su capacidad `contrato-de-datos` describe las reglas de la base
  (RLS, baja lógica, restricciones, idempotencia y vistas públicas).
- Un cambio de comportamiento compartido empieza acá, como feature de Spec Kit (si toca la base,
  incluye `contrato-de-datos` en el catálogo). Los ports siguen con OpenSpec: su change usa el mismo
  nombre que la feature (`NNN-<nombre>` sin el número) y la referencia en su `proposal.md`.
- Los cambios de esquema siguen además el runbook del vault:
  `../notas/runbooks/cambiar-el-esquema.md`. El conocimiento que cruza repos (decisiones, riesgos,
  registro de migraciones) sigue viviendo en `../notas`: las specs no lo duplican, lo enlazan.
- Las diferencias conocidas entre las tres apps están en `openspec/project.md` → "Paridad".

## Herramienta

El proceso usa Spec Kit (`specify-cli`; instalación en `CLAUDE.md`). El catálogo no necesita
ninguna herramienta: son archivos Markdown. Si se instala el CLI de OpenSpec
(`npm i -g @fission-ai/openspec`), `openspec list` y `openspec show <capacidad>` sirven para
navegar. El validador estricto espera SHALL/MUST en inglés y estas specs usan DEBE.

## Verificar en este repo

```bash
flutter analyze                       # tiene que quedar limpio
flutter test                          # unitarios, de widget y capturas (sin omitidos nuevos)
npx supabase@latest db reset          # si la feature trae migración (Supabase local)
npx supabase@latest test db           # pgTAP: RLS, RPC, restricciones y 09_contrato
```

Si la feature cambia un flujo completo, sumar o ajustar su test en `integration_test/flujos/` y
correr la integración contra el Supabase local (comandos y cuelgues conocidos en `CLAUDE.md` →
"Integración").

Un `Scenario` sin test es una tarea pendiente. Los tests omitidos (`skip: true`) son bugs
conocidos (ver `CLAUDE.md` → "Tests"): si una feature los arregla, se quita el `skip`.
