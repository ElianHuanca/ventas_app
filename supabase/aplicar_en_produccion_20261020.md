# Aplicar `20261020000000_idempotencia_y_venta_telas.sql` en producción

Proyecto `tacgylhmwqkfhdkpcvkr`. Lo aplica Elian (SQL Editor de Supabase Studio, o `psql` por el
pooler como dice `notas/runbooks/cambiar-el-esquema.md`). **Nunca `supabase db push`.**

## Orden

1. Prechequeo (solo lectura) → todo tiene que dar lo esperado.
2. Aplicar la migración (un solo `BEGIN; … COMMIT;`, ya viene en el archivo).
3. Verificación (solo lectura) + prueba funcional que se revierte sola.
4. Anotar en `notas/datos/migraciones/registro-de-migraciones.md` (la fila ya está, con fecha
   "pendiente": completar fecha, quién y la verificación).
5. **Recién después** publicar el Flutter nuevo (rama `fix/idempotencia`). Sin la migración, ese
   Flutter da error al vender (telas y apliques), al fabricar y al borrar líneas.

Entre el paso 2 y el 5 no hay que parar nada: las apps que están en los celulares (Flutter
anterior), Android e iOS siguen andando igual (llaman sin `p_id_operacion` y no usan las RPC
nuevas).

---

## 1. Prechequeo (solo lectura)

Pegar y correr. El SQL Editor muestra el resultado de la última consulta: correrlas de a una.

### 1a. Las funciones de producción son las del repo

```sql
select p.oid::regprocedure as firma,
       md5(replace(p.prosrc, E'\r', '')) as md5_cuerpo,
       p.proacl
from pg_proc p
where p.pronamespace = 'public'::regnamespace
  and p.proname in ('crear_venta_apliques', 'registrar_produccion', 'top_productos',
                    'registrar_detalle_venta', 'incrementar_venta',
                    'registrar_venta_telas', 'borrar_detalle_venta')
order by 1;
```

Esperado (5 filas, ni `registrar_venta_telas` ni `borrar_detalle_venta`):

| firma | md5_cuerpo | proacl |
|---|---|---|
| `crear_venta_apliques(bigint,text,numeric,numeric,numeric,jsonb)` | `31b75e35ed8490b2e207ca3aef85a1a2` | `{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}` |
| `registrar_produccion(bigint,date,jsonb)` | `e0eb20e57e12ab0a088c3cd7fa88ab66` | igual |
| `registrar_detalle_venta(bigint,jsonb)` | `59a3a46445dff6a5a4ea832d1bf8be44` | igual |
| `incrementar_venta(bigint,numeric,numeric,numeric,text)` | `b4fec678b2da0151856248b039a3d056` | igual |
| `top_productos(text,text)` | `e0220897e88d60ae883ad4c1c4200ccd` | `{=X/postgres,postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}` |

Los md5 son los de las migraciones del repo aplicadas en local (`md5` del cuerpo sin `\r`, como en
las verificaciones del 2026-10-07 y 2026-10-15). **Si alguno no coincide, no seguir**: alguien
cambió la función a mano y la migración la reemplazaría. (El `=X/postgres` de `top_productos` es
el `todo` conocido de `01_rls_y_permisos.test.sql`: PUBLIC conserva EXECUTE; la migración no lo
cambia.)

### 1b. Lo que la migración crea todavía no existe

```sql
select to_regclass('public.operaciones_aplicadas') as tabla,
       (select count(*) from pg_proc
         where pronamespace = 'public'::regnamespace
           and proname in ('crear_venta_apliques', 'registrar_produccion')) as funciones_con_ese_nombre;
```

Esperado: `tabla` vacía (NULL) y `funciones_con_ese_nombre` = 2 (una de cada, sin sobrecargas).

### 1c. Datos (informativo, no bloquea)

```sql
select
  (select count(*) from detalle_ventas where total is null or ganancias is null) as lineas_sin_total,
  (select count(*) from (
     select v.id from ventas v left join detalle_ventas d on d.idventa = v.id
     group by v.id, v.total
     having v.total <> coalesce(sum(d.total), 0)) x) as ventas_que_no_suman_sus_lineas;
```

`ventas_que_no_suman_sus_lineas` cuenta las ventas de telas que ya quedaron descuadradas por los
bugs que arregla esta migración (o por ventas viejas de antes del detalle). La migración **no** las
toca: anotar el número en el registro; corregirlas es otra decisión.

---

## 2. Aplicar

SQL Editor → pegar el archivo entero `supabase/migrations/20261020000000_idempotencia_y_venta_telas.sql`
→ Run. Trae su propio `BEGIN; … COMMIT;`: si algo falla, no queda nada a medias. Termina con
`NOTIFY pgrst, 'reload schema'` para que PostgREST vea las firmas nuevas enseguida.

Por el pooler (alternativa del runbook):
`docker exec -i -e PGPASSWORD=... supabase_db_ventas_app psql "<pooler-url>?sslmode=require" -v ON_ERROR_STOP=1 -f - < supabase/migrations/20261020000000_idempotencia_y_venta_telas.sql`

---

## 3. Verificación

### 3a. Firmas, resultado y cuerpos

```sql
select p.oid::regprocedure as firma,
       pg_get_function_result(p.oid) as devuelve,
       md5(replace(p.prosrc, E'\r', '')) as md5_cuerpo
from pg_proc p
where p.pronamespace = 'public'::regnamespace
  and p.proname in ('crear_venta_apliques', 'registrar_produccion', 'registrar_venta_telas',
                    'borrar_detalle_venta', 'top_productos', 'registrar_detalle_venta', 'incrementar_venta')
order by 1;
```

Esperado (7 filas, iguales a las de la base local con la migración aplicada):

| firma | devuelve | md5_cuerpo |
|---|---|---|
| `top_productos(text,text)` | `TABLE(nombre text, total_vendido numeric, total_cantidad numeric)` | `62800c9f04e0cf9c864acda79a3b4da3` |
| `registrar_detalle_venta(bigint,jsonb)` | `SETOF detalle_ventas` | `59a3a46445dff6a5a4ea832d1bf8be44` (sin cambios) |
| `incrementar_venta(bigint,numeric,numeric,numeric,text)` | `ventas` | `b4fec678b2da0151856248b039a3d056` (sin cambios) |
| `crear_venta_apliques(bigint,text,numeric,numeric,numeric,jsonb,uuid)` | `bigint` | `ee98e963bdff888474662897733bc006` |
| `registrar_produccion(bigint,date,jsonb,uuid)` | `bigint` | `86385293d45e18d65f8f40feaa2ec4eb` |
| `registrar_venta_telas(bigint,text,jsonb,numeric,uuid)` | `bigint` | `12588095ef1c6e4c37b0fcf1652dcdd1` |
| `borrar_detalle_venta(bigint)` | `ventas` | `53bcd7d83efd6eb58cf539152b13a408` |

Ya no tiene que existir `crear_venta_apliques(bigint,text,numeric,numeric,numeric,jsonb)` ni
`registrar_produccion(bigint,date,jsonb)` (con dos sobrecargas PostgREST no sabría a cuál llamar).

### 3b. Permisos de las RPC (anon nada)

```sql
select p.oid::regprocedure as firma, p.proacl,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_ejecuta,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as logueado_ejecuta
from pg_proc p
where p.pronamespace = 'public'::regnamespace
  and p.proname in ('crear_venta_apliques', 'registrar_produccion', 'registrar_venta_telas', 'borrar_detalle_venta')
order by 1;
```

Esperado: las 4 con `proacl` = `{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}`,
`anon_ejecuta` = `f`, `logueado_ejecuta` = `t`.

### 3c. La tabla nueva

```sql
select c.relrowsecurity as rls,
       (select string_agg(policyname || ' ' || cmd || ' ' || array_to_string(roles, ','), '; ')
          from pg_policies where tablename = 'operaciones_aplicadas') as politicas,
       has_table_privilege('anon', c.oid, 'SELECT') or has_table_privilege('anon', c.oid, 'INSERT')
         or has_table_privilege('anon', c.oid, 'UPDATE') or has_table_privilege('anon', c.oid, 'DELETE') as anon_algo,
       has_table_privilege('authenticated', c.oid, 'SELECT') as logueado_select,
       has_table_privilege('authenticated', c.oid, 'INSERT') as logueado_insert,
       has_table_privilege('authenticated', c.oid, 'UPDATE') as logueado_update,
       has_table_privilege('authenticated', c.oid, 'DELETE') as logueado_delete,
       has_table_privilege('authenticated', c.oid, 'TRUNCATE') as logueado_truncate,
       (select count(*) from public.operaciones_aplicadas) as filas
from pg_class c where c.oid = 'public.operaciones_aplicadas'::regclass;
```

Esperado: `t | solo_logueados_operaciones_aplicadas ALL authenticated | f | t | t | t | f | f | 0`.

### 3d. Prueba funcional que se revierte sola

El bloque **siempre** termina en error, así que nada de lo que escribe queda guardado (solo
consume algunos ids de las secuencias de `ventas`, `detalle_ventas` y `detalle_produccion`). Usa
la primera sucursal y la primera tela por id, y el día 2001-01-05 (no hay ventas reales ese día).
Corre como `authenticated`, con RLS y permisos de verdad.

```sql
DO $$
DECLARE
  v_suc    bigint := (SELECT id FROM public.sucursales ORDER BY id LIMIT 1);
  v_tela   bigint := (SELECT id FROM public.telas ORDER BY id LIMIT 1);
  v_inv    record;
  v_lineas jsonb;
  v1 bigint; v2 bigint; v3 bigint;
  v_venta   public.ventas;
  v_borrada public.ventas;
  v_stock   numeric;
  v_error   text;
BEGIN
  SET LOCAL ROLE authenticated;

  -- registrar_venta_telas: la misma clave dos veces = una sola venta
  v_lineas := jsonb_build_array(jsonb_build_object(
    'idtelas', v_tela, 'nombre', 'verificación 20261020', 'precio', 10,
    'cantidad', 1, 'total', 10, 'ganancias', 3));
  v1 := public.registrar_venta_telas(v_suc, '2001-01-05T10:00:00.000', v_lineas, 0,
                                     '00000000-0000-4000-8000-00000000f001');
  v2 := public.registrar_venta_telas(v_suc, '2001-01-05T10:00:00.000', v_lineas, 0,
                                     '00000000-0000-4000-8000-00000000f001');
  IF v1 IS DISTINCT FROM v2 THEN
    RAISE EXCEPTION 'FALLA: la misma clave devolvió otra venta (% y %)', v1, v2;
  END IF;
  SELECT * INTO v_venta FROM public.ventas WHERE id = v1;
  IF v_venta.total <> 10 OR v_venta.ganancias <> 3 THEN
    RAISE EXCEPTION 'FALLA: la venta quedó con total % y ganancias % (esperado 10 y 3)',
      v_venta.total, v_venta.ganancias;
  END IF;

  -- borrar_detalle_venta: descuenta y es idempotente
  v_borrada := public.borrar_detalle_venta((SELECT id FROM public.detalle_ventas WHERE idventa = v1));
  IF v_borrada.total <> 0 OR v_borrada.ganancias <> 0 THEN
    RAISE EXCEPTION 'FALLA: borrar_detalle_venta dejó total % y ganancias %', v_borrada.total, v_borrada.ganancias;
  END IF;
  IF (public.borrar_detalle_venta(-1)).id IS NOT NULL THEN
    RAISE EXCEPTION 'FALLA: borrar una línea que no existe devolvió una venta';
  END IF;

  -- registrar_produccion: sin clave (como Android/iOS) suma; con clave
  -- repetida, una sola vez
  SELECT i.sucursal_id, i.aplique_id, i.color_id, i.stock INTO v_inv
    FROM public.inventario i
   WHERE i.activo ORDER BY i.sucursal_id, i.aplique_id, i.color_id LIMIT 1;
  IF FOUND THEN
    v_lineas := jsonb_build_array(jsonb_build_object(
      'idaplique', v_inv.aplique_id, 'idcolor', v_inv.color_id, 'cantidad', 1));
    v3 := public.registrar_produccion(p_sucursal_id => v_inv.sucursal_id,
                                      p_fecha => '2001-01-05', p_lineas => v_lineas);
    PERFORM public.registrar_produccion(v_inv.sucursal_id, '2001-01-05', v_lineas,
                                        '00000000-0000-4000-8000-00000000f002');
    PERFORM public.registrar_produccion(v_inv.sucursal_id, '2001-01-05', v_lineas,
                                        '00000000-0000-4000-8000-00000000f002');
    SELECT stock INTO v_stock FROM public.inventario
     WHERE sucursal_id = v_inv.sucursal_id AND aplique_id = v_inv.aplique_id
       AND color_id = v_inv.color_id;
    IF v_stock <> v_inv.stock + 2 THEN
      RAISE EXCEPTION 'FALLA: el stock quedó en % (esperado %: 1 sin clave + 1 con la clave repetida)',
        v_stock, v_inv.stock + 2;
    END IF;
  END IF;

  -- crear_venta_apliques como la llaman las apps viejas (por nombre, sin
  -- p_id_operacion): tiene que llegar a la función nueva y dar su propio error
  BEGIN
    PERFORM public.crear_venta_apliques(
      p_idsucursales => v_suc, p_fecha => '2001-01-05T10:00:00.000',
      p_total => 0, p_ganancias => 0, p_descuento => 0, p_detalles => '[]'::jsonb);
    RAISE EXCEPTION 'FALLA: crear_venta_apliques aceptó una venta sin líneas';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    IF v_error <> 'La venta no tiene líneas' THEN RAISE; END IF;
  END;

  RAISE EXCEPTION 'VERIFICACIÓN OK (no queda nada guardado): misma clave = una sola vez en '
    'registrar_venta_telas (venta %) y registrar_produccion, borrar_detalle_venta descuenta y es '
    'idempotente, y las llamadas sin clave siguen andando', v1;
END $$;
```

Esperado: `ERROR: VERIFICACIÓN OK (no queda nada guardado): …`. Cualquier mensaje que empiece con
`FALLA:` (u otro error) dice qué no anduvo; tampoco deja nada guardado. Después, la consulta 3c
tiene que seguir dando `filas` = 0.

### 3e. PostgREST encuentra las firmas (sin login: tiene que dar 401, no 404)

Con la publishable key de `lib/config/supabase/supabase_config.dart`:

```bash
URL=https://tacgylhmwqkfhdkpcvkr.supabase.co/rest/v1/rpc
KEY=<publishable key>
# Como lo llaman las apps viejas, Android e iOS (6 parámetros, sin p_id_operacion)
curl -s -X POST "$URL/crear_venta_apliques" -H "apikey: $KEY" -H "Content-Type: application/json" \
  -d '{"p_idsucursales":1,"p_fecha":"2001-01-05T10:00:00","p_total":0,"p_ganancias":0,"p_descuento":0,"p_detalles":[]}'
# Como lo llama el Flutter nuevo
curl -s -X POST "$URL/registrar_venta_telas" -H "apikey: $KEY" -H "Content-Type: application/json" \
  -d '{"p_idsucursales":1,"p_fecha":"2001-01-05T10:00:00","p_detalles":[],"p_descuento":0,"p_id_operacion":"00000000-0000-4000-8000-00000000f003"}'
curl -s -X POST "$URL/borrar_detalle_venta" -H "apikey: $KEY" -H "Content-Type: application/json" -d '{"p_id":-1}'
```

Esperado en las tres: `{"code":"42501",…,"message":"permission denied for function …"}` (PostgREST
encontró la función y `anon` no la puede ejecutar). Un `PGRST202` ("Could not find the function")
quiere decir que PostgREST no recargó el esquema: correr `NOTIFY pgrst, 'reload schema';` y repetir.

---

## Si hay que volver atrás

Solo **antes** de publicar el Flutter nuevo (ese Flutter necesita las RPC nuevas). Restaura las
firmas y los cuerpos de antes (md5 `31b75e…` y `e0eb20…`, probado en local dentro de una
transacción revertida) y borra la tabla; `top_productos` con `COALESCE` se puede dejar.

```sql
BEGIN;
DROP FUNCTION public.registrar_venta_telas(bigint, text, jsonb, numeric, uuid);
DROP FUNCTION public.borrar_detalle_venta(bigint);
DROP FUNCTION public.crear_venta_apliques(bigint, text, numeric, numeric, numeric, jsonb, uuid);
DROP FUNCTION public.registrar_produccion(bigint, date, jsonb, uuid);
DROP TABLE public.operaciones_aplicadas;
-- Pegar acá, tal cual, el CREATE OR REPLACE FUNCTION public.crear_venta_apliques(...) de
-- supabase/migrations/20261007000000_venta_apliques_colores_vinculados.sql (líneas 17-89) y el
-- CREATE OR REPLACE FUNCTION public.registrar_produccion(...) de
-- supabase/migrations/20261003000100_integridad_stock_y_ventas.sql (líneas 146-178).
REVOKE ALL ON FUNCTION public.crear_venta_apliques(bigint, text, numeric, numeric, numeric, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.registrar_produccion(bigint, date, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crear_venta_apliques(bigint, text, numeric, numeric, numeric, jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.registrar_produccion(bigint, date, jsonb) TO authenticated, service_role;
NOTIFY pgrst, 'reload schema';
COMMIT;
```

Después, la consulta 1a tiene que volver a dar los md5 del prechequeo.
