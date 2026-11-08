# Ordenar los colores de una tela de la A a la Z

## Por qué

La pantalla de colores de una tela (`/tela-colores/:idtela`) lista los colores **de la Z a la A**:
`TelasDatasourceImpl.getColoresTela` pide `.order('nombre')` y postgrest-dart, si no se le pasa
`ascending: true`, le pide `nombre.desc` a PostgREST. Además no los reordena sin distinguir
mayúsculas, como sí hacen el listado de colores (`ColoresDatasourceImpl.getColores`) y los colores
de un aplique (`ApliquesDatasourceImpl.getColoresAplique`): un color cargado en minúscula
("azul") queda fuera de lugar.

Android (`TelasDatasourceImpl.getColoresTela`: `order("nombre", Order.ASCENDING)` +
`sortedBy { it.nombre.lowercase() }`) los muestra de la A a la Z sin distinguir mayúsculas, y
su spec lo marca como diferencia con Flutter (`<!-- paridad: -->`). Acá lo marca el
`<!-- revisar: telas_datasource_impl.dart:76 -->` de `specs/telas/spec.md`, que hoy no fija el
orden de esa pantalla.

## Qué cambia

- Los colores de una tela se listan **por nombre, de la A a la Z, sin distinguir mayúsculas**:
  igual que en Android, en el listado de colores y en los colores de un aplique.
- `TelasDatasourceImpl.getColoresTela` pide `ascending: true` y reordena por el nombre en
  minúsculas (el mismo criterio que `getColoresAplique`).
- El Requirement "Ver los colores de una tela" suma el orden y un escenario que lo fija, y sale
  el `revisar`.

No cambia nada más: siguen apareciendo los mismos colores (solo los activos) con el mismo
interruptor y el mismo vínculo.

## Capacidades afectadas

- `telas`: MODIFIED "Ver los colores de una tela".

## Impacto

- **Android**: sin cambios de código; ya los ordena así (es la referencia que se iguala). Su
  `<!-- paridad: -->` del Requirement "Ver los colores de una tela" deja de aplicar y se puede
  quitar en ese repo.
- **iOS** (`../ventas_app_ios`, `TelasSupabase.getColoresTela`): `.order("nombre")` de
  supabase-swift ya es ascendente por defecto, pero no reordena sin mayúsculas (su spec tiene el
  mismo `revisar`). Queda como diferencia de paridad menor; este change no lo toca.
- **Base de datos**: ninguno. Sin migración ni RPC; la consulta es la misma salvo el sentido del
  `order`.
- **Datos de producción**: ninguno.
- **Landing (`sitio`)**: ninguno. `catalogo_telas_web` ya publica los colores ordenados sin
  mayúsculas.
