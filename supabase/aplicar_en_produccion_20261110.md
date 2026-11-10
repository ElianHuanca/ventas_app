# Aplicar en producción: 20261110000000_saneamiento_catalogo.sql

Aditiva e idempotente. La aplica el dueño (Supabase Studio → SQL Editor, o `psql` por el pooler IPv4, ver runbook).

## Prechequeo (solo lectura)
```sql
select (select count(*) from telas where categoria_id is null)    as telas_sin_categoria,     -- esperado 30
       (select count(*) from apliques where categoria_id is null) as apliques_sin_categoria,  -- esperado 2
       (select count(*) from telas where nombre <> btrim(nombre) or left(nombre,1) <> upper(left(nombre,1))) as telas_nombre_sucio, -- esperado 3
       (select count(*) from colores c where exists (select 1 from colores d where d.id <> c.id and lower(btrim(d.nombre)) = lower(btrim(c.nombre)))) as colisiones_colores; -- esperado 0
```

## Aplicar
Pegar el archivo completo (ya trae `begin; … commit;`).

## Verificación
```sql
select (select count(*) from telas where categoria_id is null) + (select count(*) from apliques where categoria_id is null) as sin_categoria, -- 0
       (select count(*) from telas where nombre <> btrim(nombre) or left(nombre,1) <> upper(left(nombre,1)))
     + (select count(*) from apliques where nombre <> btrim(nombre) or left(nombre,1) <> upper(left(nombre,1)))
     + (select count(*) from colores where nombre <> btrim(nombre) or left(nombre,1) <> upper(left(nombre,1))) as nombres_sucios, -- 0
       (select count(*) from pg_trigger where tgname = 'normalizar_nombre' and not tgisinternal) as disparadores, -- 3
       (select column_default from information_schema.columns where table_name='telas' and column_name='categoria_id') as default_telas; -- 1
```
Después: `uv run huantex actualizar` en `huantex_datos` → `producto_sin_categoria` y `producto_nombre_mal_escrito` en 0.