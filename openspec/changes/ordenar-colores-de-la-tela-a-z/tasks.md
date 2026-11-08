# Tareas: ordenar-colores-de-la-tela-a-z

## 1. Tests (primero: tienen que fallar antes del cambio)

- [ ] 1.1 `test/features/telas/infrastructure/datasources/telas_datasource_impl_test.dart`:
      `getColoresTela` contra la base falsa, con los colores desordenados a propósito y con
      mayúsculas y minúsculas mezcladas, los trae por nombre de la A a la Z sin distinguir
      mayúsculas (y sin los dados de baja).
- [ ] 1.2 Mismo archivo: la pantalla de colores de la tela, con el cubit, el repositorio y el
      datasource reales, muestra los interruptores en ese orden.

## 2. Implementación

- [ ] 2.1 `TelasDatasourceImpl.getColoresTela`: `.order('nombre', ascending: true)` y reordenar
      por `nombre.toLowerCase()`, como `ApliquesDatasourceImpl.getColoresAplique`.

## 3. Verificación

- [ ] 3.1 `flutter analyze` limpio.
- [ ] 3.2 `flutter test` completo. Las capturas de `tela_colores` no cambian: usan un repositorio
      falso que ya entrega los colores en un orden fijo.

## 4. Archivo

- [ ] 4.1 Aplicar el delta a `openspec/specs/telas/spec.md` (con sus anclas `<!-- test: -->`),
      sacar el `revisar` y actualizar el `Last verified`.
- [ ] 4.2 Mover el change a `openspec/changes/archive/2026-11-08-ordenar-colores-de-la-tela-a-z/`.
