# Implementation Plan: Saneamiento del catálogo
**Branch**: `feat/saneamiento-catalogo` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary
Una migración aditiva (defaults + relleno + función/disparadores de normalización de nombre), un test pgTAP, el
Invariant en el catálogo openspec de telas/apliques/colores, la fila del registro del vault y la nota de aplicación
a producción (prechequeo/verificación). Validación previa sobre la copia local `huantex_dw`.

## Constitution Check
I (spec → código) ✅ · II (migración nueva, aditiva, sin tocar las aplicadas; runbook y registro) ✅ · tests pgTAP ✅.
**Desvío declarado**: la constitución pide probar con `npx supabase db reset`; esta vez se valida sobre `huantex_dw`
(volcado exacto de producción, Postgres 17) porque levantar el stack local de Supabase supera la RAM disponible en
esta sesión. El test pgTAP queda listo para la próxima vez que se corra `supabase test db`.

## Project Structure
```text
supabase/migrations/20261110000000_saneamiento_catalogo.sql
supabase/tests/database/11_saneamiento_catalogo.test.sql
supabase/aplicar_en_produccion_20261110.md
openspec/specs/telas/spec.md, apliques/spec.md, colores/spec.md   (+ Invariant)
../notas/datos/migraciones/registro-de-migraciones.md             (+ fila)
```