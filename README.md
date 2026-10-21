# ventas_app (Huantex)

[![CI](https://github.com/ElianHuanca/ventas_app/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/ElianHuanca/ventas_app/actions/workflows/ci.yml)
[![Noche](https://github.com/ElianHuanca/ventas_app/actions/workflows/noche.yml/badge.svg?branch=main)](https://github.com/ElianHuanca/ventas_app/actions/workflows/noche.yml)
[![Semanal](https://github.com/ElianHuanca/ventas_app/actions/workflows/semanal.yml/badge.svg?branch=main)](https://github.com/ElianHuanca/ventas_app/actions/workflows/semanal.yml)

App Flutter de punto de venta de telas y apliques para Huantex, sobre Supabase
(PostgreSQL). La guía completa del proyecto (arquitectura, esquema, entorno
local y cómo se corre cada tipo de test) está en [`CLAUDE.md`](CLAUDE.md).

## CI (GitHub Actions)

Todo corre en runners de GitHub, con Flutter **3.38.9** fijo
(`.github/actions/flutter`). Los jobs que necesitan base levantan un Supabase
local en Docker con las migraciones de `supabase/migrations/` (sin seed) y
reescriben `env/local*.json` con sus claves (`.github/actions/supabase-local`).

| Workflow | Cuándo | Qué corre |
|---|---|---|
| [`ci.yml`](.github/workflows/ci.yml) | cada PR y cada push a `main` | `flutter analyze`; `flutter test --exclude-tags golden --coverage` (unitarios, widget, propiedades, accesibilidad, fugas) con cobertura mínima (`tool/cobertura.dart`); capturas golden en Windows; pgTAP (`supabase test db`); `flutter build apk --debug` |
| [`noche.yml`](.github/workflows/noche.yml) | todos los días 06:00 UTC, o a mano | concurrencia y red contra Supabase local; integración completa en un emulador Android (API 34); micro-benchmarks (informativos) |
| [`semanal.yml`](.github/workflows/semanal.yml) | domingos 07:00 UTC, o a mano | mutación (`mutacion/*.xml`) en Windows, un job por XML |

- Un push nuevo a un PR cancela la corrida anterior del mismo PR.
- Si fallan las capturas, el job sube las imágenes de diferencia
  (`test/goldens/**/failures/`) como artifact. También quedan como artifacts el
  `lcov.info`, los resultados de los micro-benchmarks y los reportes de mutación.
- Cobertura local, igual que en la CI:

  ```bash
  flutter test --exclude-tags golden --coverage
  dart run tool/cobertura.dart --minimo 83
  ```

- `noche.yml` y `semanal.yml` se lanzan a mano desde la pestaña Actions
  (**Run workflow**).
