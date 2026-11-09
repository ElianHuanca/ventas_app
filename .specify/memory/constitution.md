# Constitución de ventas_app (Huantex)

## Core Principles

### I. La especificación es la fuente de verdad

- Todo cambio de comportamiento (feature o pantalla nueva; regla, cálculo, validación o mensaje
  que ve el usuario; RPC, tabla, columna o política; quitar un flujo) DEBE pasar por el flujo de
  Spec Kit antes de tocar código: `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` →
  `/speckit-tasks` → `/speckit-analyze` → `/speckit-implement` → `/speckit-converge`.
  Refactors sin efecto observable, tests de comportamiento ya especificado, lints y dependencias
  sin efecto observable van directo.
- `openspec/specs/<capacidad>/spec.md` es el catálogo del comportamiento VIGENTE de la app. Toda
  feature que cambie comportamiento DEBE actualizar ahí la capacidad afectada, en el mismo PR que el
  código: Requirement/Invariant con DEBE / NO DEBE, sus `#### Scenario:` con el ancla
  `<!-- test: -->` y el `<!-- enforced: -->` al día, y el `Last verified` actualizado. Una spec del
  catálogo siempre describe código mergeado.
- Si el código y la spec no coinciden, uno de los dos tiene un bug. `<!-- revisar: -->` marca un
  comportamiento actual dudoso y solo se resuelve con una feature.
- Cero código sombra: se construye solo lo especificado. Nada "por si acaso".
- Si un pedido contradice esta constitución o una spec, o si se detecta una falla lógica, el
  agente DEBE detenerse, explicar el problema y pedir que se actualice la spec antes de escribir
  código.

Razón: la app es la referencia de comportamiento de los ports Android e iOS y comparte la base con
la landing; sin una spec al día, el desvío se multiplica en cuatro proyectos.

### II. Una base compartida; este repo es el dueño del esquema

- Una sola base Supabase alimenta ventas_app (Flutter), ventas_app_android, ventas_app_ios y la
  landing `sitio`. `supabase/migrations/` es la fuente de verdad del esquema.
- Todo cambio de esquema DEBE ser una migración nueva `<timestamp>_*.sql`. Las migraciones aplicadas
  NO DEBEN editarse y `supabase/schema.sql` (obsoleto) NO DEBE reaplicarse. Se prueba con
  `npx supabase@latest db reset` en local y sigue el runbook `../notas/runbooks/cambiar-el-esquema.md`
  (incluido el registro de migraciones del vault).
- Antes de renombrar o borrar una columna o un parámetro de una RPC DEBE correrse
  `npx supabase@latest test db`: `09_contrato.test.sql` dice qué app se rompe.
- Los parámetros nuevos de una RPC DEBEN ir al final y con `DEFAULT`, para que las apps viejas y los
  ports sigan andando.
- Paridad: Flutter, Android e iOS usan los mismos nombres de Requirement. Una feature que cambia
  comportamiento compartido DEBE anotar en su spec el impacto en Android, iOS y `sitio` (si toca una
  vista pública o una columna que ellas leen).

Razón: un cambio de esquema mal propagado rompe en silencio apps que no están en este repo.

### III. Integridad de los datos en la base (NO NEGOCIABLE)

- Toda escritura que toque más de una tabla DEBE ser una RPC transaccional. NO DEBE volverse al
  patrón leer → sumar en el cliente → escribir, ni encadenar llamadas desde la app.
- Las RPC de escritura con carrito DEBEN recibir una clave de idempotencia (`p_id_operacion`) que la
  app genera con `ClaveDeOperacion`: la misma en los reintentos del mismo envío, otra si cambió lo que
  se manda.
- Baja lógica en todo: dar de baja es `activo = false`. NO DEBE haber `DELETE` físico salvo en
  `ventas` y `detalle_ventas`, ni `TRUNCATE` en nada. Los listados para vender, fabricar o publicar
  filtran `activo = true`.
- Las reglas de negocio críticas DEBEN hacerse cumplir en la base, no solo en la UI: stock ≥ 0,
  cantidades > 0, precios y costos ≥ 0, una venta (telas y apliques) y una producción por
  sucursal+día, colores vinculados al aplique para venderlo.
- El dinero es `NUMERIC` (nunca coma flotante) y `fecha` se guarda como TEXT ISO8601, porque las RPC
  la comparan como texto.

Razón: hay varios dispositivos vendiendo a la vez y redes que se cortan; la base es la única que ve
todas las escrituras.

### IV. Login obligatorio y datos públicos mínimos

- Toda tabla DEBE tener RLS y exactamente una política `solo_logueados_<tabla>`. Sin ella PostgREST
  devuelve `[]` en silencio.
- `anon` NO DEBE leer ni escribir tablas ni RPC: solo las vistas `*_web`, que NO DEBEN exponer
  `precxcompra`, `costo_fabricacion`, el stock ni montos vendidos. Toda vista o RPC pública nueva
  lleva su `GRANT` explícito.
- No hay registro desde la app: las cuentas se crean en Supabase. Modelo vigente: logueado = acceso
  total, sin roles; introducir roles es una feature.
- Credenciales y claves de firma (`key.properties`, `.jks`, contraseñas de la base) NO DEBEN entrar
  a git ni a ningún archivo versionado.

### V. Tests primero y verificables

- Cada `Scenario` DEBE quedar cubierto por al menos un test que primero falla y después pasa. Un
  Scenario sin test es una tarea pendiente.
- Antes de dar una feature por terminada DEBEN pasar: `flutter analyze` sin problemas; `flutter test`
  (unitarios, de widget y capturas) sin omitidos nuevos; pgTAP (`npx supabase@latest test db`) si
  hay migración; y el flujo de `integration_test/flujos/` contra el Supabase local si cambia un flujo
  completo.
- Un bug real que aparece al escribir tests NO se arregla desde el test: se documenta con
  `// bug: archivo:línea — qué pasa`, el test queda omitido y se resuelve con una feature. Si una
  feature lo arregla, se quita la omisión.
- Las pruebas NUNCA corren contra producción: se usa el Supabase local de Docker.

### VI. Seguir la arquitectura existente

- Clean Architecture por feature en `lib/features/<feature>/` (`domain`, `infrastructure`,
  `presentation`). BLoC para el estado de las features y Cubit para los formularios. Los providers se
  crean por ruta en `lib/config/router/app_router.dart` (GoRouter).
- Los datasources usan el cliente compartido `SupabaseConfig.client`.
- Todo texto que ve el usuario está en español.
- Simplicidad: no agregar capas, patrones ni dependencias que la feature no necesite. Toda
  dependencia nueva se justifica en el plan.

## Restricciones técnicas

- Stack: Flutter (Dart ≥ 3.0.6), Material 3, `flutter_bloc`, `go_router`, `supabase_flutter`
  (PostgreSQL + Auth + Storage). Las mismas versiones mayores salvo que el plan justifique subirlas.
- `postgrest-dart` ordena descendente por defecto: todo `.order()` DEBE pedir `ascending: true` o
  `false` en forma explícita.
- Fotos: bucket público `fotos` de Storage, 5 MB, solo JPEG, PNG o WebP; quitar una foto es baja
  lógica (el archivo queda).
- El conocimiento que cruza repositorios (decisiones, riesgos, registro de migraciones, runbooks)
  vive en el vault `../notas`: las specs y los planes lo enlazan, no lo duplican.

## Flujo de trabajo y calidad

- Cada feature vive en `specs/NNN-<nombre>/` (`spec.md`, `plan.md`, `tasks.md` y lo que generen las
  skills) y en una rama propia.
- `/speckit-clarify` es obligatorio antes de `/speckit-plan`: las decisiones de negocio las toma la
  persona, no la IA.
- `/speckit-plan` DEBE pasar el "Constitution Check" de esta constitución; toda excepción se
  justifica por escrito en el plan.
- `/speckit-analyze` DEBE correr antes de `/speckit-implement`, y `/speckit-converge` al terminar,
  para que el código coincida con la spec.
- `tasks.md` incluye como tareas actualizar `openspec/specs/` y, si corresponde, avisar el impacto
  en Android, iOS y `sitio`.
- Commits chicos y frecuentes. Push, PR y merge solo con el OK explícito del dueño del proyecto.
- Cuando cambia el negocio: se actualiza el artefacto más alto afectado (`/speckit-clarify` sobre la
  spec, o esta constitución), se propaga spec → plan → tareas → código (`/speckit-plan` a
  `/speckit-converge`) y se vuelve a auditar.

## Governance

- Esta constitución manda sobre cualquier otra práctica del repo. `CLAUDE.md` es la guía operativa
  (comandos, convenciones, detalles) y NO DEBE contradecirla; si lo hace, se corrige `CLAUDE.md`.
- Las enmiendas se hacen con `/speckit-constitution`, quedan en un commit `docs:` propio y siguen
  semver: MAJOR si se quita o redefine un principio, MINOR si se agrega un principio o sección o se
  amplía materialmente, PATCH si solo se aclara la redacción.
- Cumplimiento: `/speckit-analyze` y la revisión de cada PR verifican estos principios. Toda
  complejidad extra o excepción se justifica en el plan de la feature.

**Version**: 1.0.0 | **Ratified**: 2026-11-08 | **Last Amended**: 2026-11-08
