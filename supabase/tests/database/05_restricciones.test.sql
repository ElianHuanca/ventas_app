-- =====================================================================
-- Restricciones de integridad (en la base, no solo en la UI)
--
-- Migraciones 20261003000100_integridad_stock_y_ventas.sql y
-- 20261004000100_venta_apliques_por_dia.sql:
--   * CHECK: inventario.stock >= 0, cantidades > 0, precios/costos/montos >= 0;
--   * UNIQUE: una venta de telas y una de apliques por sucursal+día, una
--     producción por sucursal+fecha, y una línea por (idventa, idtelas,
--     precio), (idventa, idapliques, idcolor, precio) y (idproduccion,
--     idaplique, idcolor).
--
-- Corre como authenticated (el rol de la app). Rollback al final.
-- =====================================================================
begin;
select plan(50);

-- ---------------------------------------------------------------------
-- Datos de apoyo (solo viven en esta transacción)
-- ---------------------------------------------------------------------
create temp table _ids (clave text primary key, id bigint not null) on commit drop;
grant all on _ids to public;
create function pg_temp.id(p_clave text) returns bigint
  language sql stable
  as $$ select id from pg_temp._ids where clave = p_clave $$;

create function pg_temp.max_id(p_tabla regclass) returns bigint
  language plpgsql stable
  as $$
declare
  v_max bigint;
begin
  execute format('select max(id) from %s', p_tabla) into v_max;
  return v_max;
end
$$;

-- =====================================================================
-- Secuencias de id: van por delante de los datos
--
-- Mira los DATOS cargados, no solo el esquema: en una base vacía pasa
-- siempre; con el seed (copia de producción) muestra el problema hasta
-- que la secuencia se use lo suficiente o se corrija con setval.
-- =====================================================================
select todo('bug: supabase/ventas_apliques.sql:37 — la migración 10 copió las ventas de apliques con OVERRIDING SYSTEM VALUE (ids 1001–1017) y nunca hizo setval: ventas_apliques_id_seq arrancó en 1 (así está en el dump de producción del 2026-09-25) y, al llegar a 1001, crear_venta_apliques va a fallar con duplicate key en ventas_apliques_pkey una vez por cada id ocupado', 1);
select is_empty($$
  select c.relname,
         coalesce(pg_sequence_last_value(s.seqrelid), 0) as ultimo_valor,
         pg_temp.max_id(c.oid) as max_id
  from pg_sequence s
  join pg_class sc on sc.oid = s.seqrelid and sc.relnamespace = 'public'::regnamespace
  join pg_depend d on d.objid = s.seqrelid and d.classid = 'pg_class'::regclass and d.deptype = 'i'
  join pg_class c on c.oid = d.refobjid
  where pg_temp.max_id(c.oid) > coalesce(pg_sequence_last_value(s.seqrelid), 0)
$$, 'ninguna secuencia de id quedó por detrás del máximo id de su tabla (si no, el próximo insert choca con la PK)');

do $$
declare
  v_suc bigint; v_otra bigint; v_tela bigint; v_rojo bigint; v_azul bigint; v_aplique bigint;
  v_venta bigint; v_venta_aplique bigint; v_produccion bigint;
begin
  insert into public.sucursales (nombre) values ('pgTAP sucursal') returning id into v_suc;
  insert into public.sucursales (nombre) values ('pgTAP otra sucursal') returning id into v_otra;
  insert into public.telas (nombre, precxmen) values ('pgTAP lino', 10) returning id into v_tela;
  insert into public.colores (nombre) values ('pgTAP rojo') returning id into v_rojo;
  insert into public.colores (nombre) values ('pgTAP azul') returning id into v_azul;
  insert into public.apliques (nombre, costo_fabricacion) values ('pgTAP Mariposa', 6) returning id into v_aplique;
  insert into public.aplique_colores (idaplique, idcolor) values (v_aplique, v_rojo);
  insert into public.tela_colores (idtela, idcolor) values (v_tela, v_rojo);
  insert into public.tela_sucursales (idtela, idsucursal) values (v_tela, v_suc);
  insert into public.inventario (sucursal_id, aplique_id, color_id, stock) values (v_suc, v_aplique, v_rojo, 0);

  insert into public.ventas (fecha, idsucursales) values ('2187-03-10T08:00:00.000', v_suc)
    returning id into v_venta;
  insert into public.detalle_ventas (nombre, precio, cantidad, total, ganancias, idtelas, idventa)
    values ('pgTAP lino', 10, 1, 10, 3, v_tela, v_venta);
  insert into public.ventas_apliques (fecha, idsucursales) values ('2187-03-10T08:00:00.000', v_suc)
    returning id into v_venta_aplique;
  insert into public.detalle_ventas_apliques (idventa, idapliques, idcolor, nombre, precio, cantidad, total, ganancias)
    values (v_venta_aplique, v_aplique, v_rojo, 'pgTAP Mariposa', 10, 1, 10, 4);
  insert into public.producciones (fecha, sucursal_id) values ('2187-03-10', v_suc)
    returning id into v_produccion;
  insert into public.detalle_produccion (idproduccion, idaplique, idcolor, cantidad)
    values (v_produccion, v_aplique, v_rojo, 1);

  insert into pg_temp._ids values
    ('sucursal', v_suc), ('otra_sucursal', v_otra), ('tela', v_tela),
    ('rojo', v_rojo), ('azul', v_azul), ('aplique', v_aplique),
    ('venta', v_venta), ('venta_aplique', v_venta_aplique), ('produccion', v_produccion);
end
$$;

set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-0000000000a5", "role": "authenticated"}';

-- =====================================================================
-- Catálogo: las restricciones existen (y los CHECK están validados)
-- =====================================================================
select set_has($$
  select conrelid::regclass::text, conname::text
  from pg_constraint
  where connamespace = 'public'::regnamespace and contype = 'c' and convalidated
$$, $$ values
  ('inventario', 'inventario_stock_no_negativo'),
  ('detalle_produccion', 'detalle_produccion_cantidad_check'),
  ('detalle_ventas', 'detalle_ventas_montos_check'),
  ('detalle_ventas_apliques', 'detalle_ventas_apliques_montos_check'),
  ('telas', 'telas_precios_no_negativos'),
  ('apliques', 'apliques_costo_no_negativo'),
  ('ventas', 'ventas_descuento_no_negativo'),
  ('ventas_apliques', 'ventas_apliques_montos_check')
$$, 'los CHECK de stock, cantidades, precios y montos existen y están validados');

select col_is_unique('public', 'producciones', array['sucursal_id', 'fecha']::name[],
  'producciones: UNIQUE (sucursal_id, fecha)');
select col_is_unique('public', 'detalle_produccion', array['idproduccion', 'idaplique', 'idcolor']::name[],
  'detalle_produccion: UNIQUE (idproduccion, idaplique, idcolor)');
select col_is_unique('public', 'detalle_ventas', array['idventa', 'idtelas', 'precio']::name[],
  'detalle_ventas: UNIQUE (idventa, idtelas, precio)');
select col_is_unique('public', 'detalle_ventas_apliques', array['idventa', 'idapliques', 'idcolor', 'precio']::name[],
  'detalle_ventas_apliques: UNIQUE (idventa, idapliques, idcolor, precio)');
select col_is_pk('public', 'inventario', array['sucursal_id', 'aplique_id', 'color_id']::name[],
  'inventario: PK (sucursal_id, aplique_id, color_id)');

select is(
  pg_get_indexdef('public.ventas_sucursal_dia_key'::regclass),
  'CREATE UNIQUE INDEX ventas_sucursal_dia_key ON public.ventas USING btree (idsucursales, "left"(fecha, 10))',
  'ventas: UNIQUE por sucursal y día (los 10 primeros caracteres de la fecha ISO8601)'
);
select is(
  pg_get_indexdef('public.ventas_apliques_sucursal_dia_key'::regclass),
  'CREATE UNIQUE INDEX ventas_apliques_sucursal_dia_key ON public.ventas_apliques USING btree (idsucursales, "left"(fecha, 10))',
  'ventas_apliques: UNIQUE por sucursal y día'
);

-- =====================================================================
-- CHECK: nada negativo, cantidades > 0
-- =====================================================================
select throws_ok($$
  insert into public.inventario (sucursal_id, aplique_id, color_id, stock)
  values (pg_temp.id('sucursal'), pg_temp.id('aplique'), pg_temp.id('azul'), -1)
$$, '23514', 'new row for relation "inventario" violates check constraint "inventario_stock_no_negativo"',
'inventario: no acepta stock negativo');

select lives_ok($$
  insert into public.inventario (sucursal_id, aplique_id, color_id, stock)
  values (pg_temp.id('sucursal'), pg_temp.id('aplique'), pg_temp.id('azul'), 0)
$$, 'inventario: stock 0 está permitido');

select throws_ok($$
  update public.inventario set stock = stock - 1
  where sucursal_id = pg_temp.id('sucursal') and aplique_id = pg_temp.id('aplique') and color_id = pg_temp.id('rojo')
$$, '23514', 'new row for relation "inventario" violates check constraint "inventario_stock_no_negativo"',
'inventario: descontar por debajo de 0 falla');

select throws_ok($$
  insert into public.detalle_produccion (idproduccion, idaplique, idcolor, cantidad)
  values (pg_temp.id('produccion'), pg_temp.id('aplique'), pg_temp.id('azul'), 0)
$$, '23514', 'new row for relation "detalle_produccion" violates check constraint "detalle_produccion_cantidad_check"',
'detalle_produccion: no acepta cantidad 0');

select throws_ok($$
  insert into public.detalle_produccion (idproduccion, idaplique, idcolor, cantidad)
  values (pg_temp.id('produccion'), pg_temp.id('aplique'), pg_temp.id('azul'), -1)
$$, '23514', 'new row for relation "detalle_produccion" violates check constraint "detalle_produccion_cantidad_check"',
'detalle_produccion: no acepta cantidad negativa');

select throws_ok($$
  insert into public.detalle_ventas (nombre, precio, cantidad, total, ganancias, idtelas, idventa)
  values ('pgTAP lino', 11, 0, 0, 0, pg_temp.id('tela'), pg_temp.id('venta'))
$$, '23514', 'new row for relation "detalle_ventas" violates check constraint "detalle_ventas_montos_check"',
'detalle_ventas: no acepta cantidad 0');

select throws_ok($$
  insert into public.detalle_ventas (nombre, precio, cantidad, total, ganancias, idtelas, idventa)
  values ('pgTAP lino', -1, 1, 0, 0, pg_temp.id('tela'), pg_temp.id('venta'))
$$, '23514', 'new row for relation "detalle_ventas" violates check constraint "detalle_ventas_montos_check"',
'detalle_ventas: no acepta precio negativo');

select lives_ok($$
  insert into public.detalle_ventas (nombre, precio, cantidad, total, ganancias, idtelas, idventa)
  values ('pgTAP lino', 0, 1, 0, 0, pg_temp.id('tela'), pg_temp.id('venta'))
$$, 'detalle_ventas: precio 0 está permitido');

select throws_ok($$
  insert into public.detalle_ventas_apliques (idventa, idapliques, idcolor, nombre, precio, cantidad, total, ganancias)
  values (pg_temp.id('venta_aplique'), pg_temp.id('aplique'), pg_temp.id('rojo'), 'pgTAP Mariposa', 11, 0, 0, 0)
$$, '23514', 'new row for relation "detalle_ventas_apliques" violates check constraint "detalle_ventas_apliques_montos_check"',
'detalle_ventas_apliques: no acepta cantidad 0');

select throws_ok($$
  insert into public.detalle_ventas_apliques (idventa, idapliques, idcolor, nombre, precio, cantidad, total, ganancias)
  values (pg_temp.id('venta_aplique'), pg_temp.id('aplique'), pg_temp.id('rojo'), 'pgTAP Mariposa', -1, 1, 0, 0)
$$, '23514', 'new row for relation "detalle_ventas_apliques" violates check constraint "detalle_ventas_apliques_montos_check"',
'detalle_ventas_apliques: no acepta precio negativo');

select throws_ok($$
  insert into public.detalle_ventas_apliques (idventa, idapliques, idcolor, nombre, precio, cantidad, total, ganancias)
  values (pg_temp.id('venta_aplique'), pg_temp.id('aplique'), pg_temp.id('rojo'), 'pgTAP Mariposa', 11, 1, -1, 0)
$$, '23514', 'new row for relation "detalle_ventas_apliques" violates check constraint "detalle_ventas_apliques_montos_check"',
'detalle_ventas_apliques: no acepta total negativo');

select throws_ok(
  format($$ insert into public.telas (nombre, %I) values ('pgTAP negativa', -1) $$, columna),
  '23514', 'new row for relation "telas" violates check constraint "telas_precios_no_negativos"',
  format('telas: no acepta %s negativo', columna)
) from unnest(array['precxmen', 'precxmay', 'precxrollo', 'precxcompra']) columna;

select lives_ok($$
  insert into public.telas (nombre, precxmen, precxmay, precxrollo, precxcompra)
  values ('pgTAP sin precio', 0, 0, 0, 0)
$$, 'telas: precio 0 está permitido (= no se vende en esa modalidad)');

select throws_ok($$
  insert into public.apliques (nombre, costo_fabricacion) values ('pgTAP negativo', -1)
$$, '23514', 'new row for relation "apliques" violates check constraint "apliques_costo_no_negativo"',
'apliques: no acepta costo de fabricación negativo');

select lives_ok($$
  insert into public.apliques (nombre, costo_fabricacion) values ('pgTAP sin costo', 0)
$$, 'apliques: costo 0 está permitido');

select throws_ok($$
  update public.ventas set descuento = -1 where id = pg_temp.id('venta')
$$, '23514', 'new row for relation "ventas" violates check constraint "ventas_descuento_no_negativo"',
'ventas: no acepta descuento negativo');

select throws_ok($$
  update public.ventas_apliques set total = -1 where id = pg_temp.id('venta_aplique')
$$, '23514', 'new row for relation "ventas_apliques" violates check constraint "ventas_apliques_montos_check"',
'ventas_apliques: no acepta total negativo');

select throws_ok($$
  update public.ventas_apliques set descuento = -1 where id = pg_temp.id('venta_aplique')
$$, '23514', 'new row for relation "ventas_apliques" violates check constraint "ventas_apliques_montos_check"',
'ventas_apliques: no acepta descuento negativo');

-- =====================================================================
-- UNIQUE: cabeceras por sucursal+día y líneas únicas
-- =====================================================================
select throws_ok($$
  insert into public.ventas (fecha, idsucursales) values ('2187-03-10T20:00:00.000', pg_temp.id('sucursal'))
$$, '23505', 'duplicate key value violates unique constraint "ventas_sucursal_dia_key"',
'ventas: una sola venta de telas por sucursal y día (aunque cambie la hora)');
select lives_ok($$
  insert into public.ventas (fecha, idsucursales) values ('2187-03-11T08:00:00.000', pg_temp.id('sucursal'))
$$, 'ventas: la misma sucursal otro día sí');
select lives_ok($$
  insert into public.ventas (fecha, idsucursales) values ('2187-03-10T08:00:00.000', pg_temp.id('otra_sucursal'))
$$, 'ventas: otra sucursal el mismo día sí');

select throws_ok($$
  insert into public.ventas_apliques (fecha, idsucursales) values ('2187-03-10T20:00:00.000', pg_temp.id('sucursal'))
$$, '23505', 'duplicate key value violates unique constraint "ventas_apliques_sucursal_dia_key"',
'ventas_apliques: una sola venta de apliques por sucursal y día (aunque cambie la hora)');
select lives_ok($$
  insert into public.ventas_apliques (fecha, idsucursales) values ('2187-03-11T08:00:00.000', pg_temp.id('sucursal'))
$$, 'ventas_apliques: la misma sucursal otro día sí');
select lives_ok($$
  insert into public.ventas_apliques (fecha, idsucursales) values ('2187-03-10T08:00:00.000', pg_temp.id('otra_sucursal'))
$$, 'ventas_apliques: otra sucursal el mismo día sí');

select throws_ok($$
  insert into public.producciones (fecha, sucursal_id) values ('2187-03-10', pg_temp.id('sucursal'))
$$, '23505', 'duplicate key value violates unique constraint "producciones_sucursal_fecha_key"',
'producciones: una sola producción por sucursal y fecha');
select lives_ok($$
  insert into public.producciones (fecha, sucursal_id) values ('2187-03-11', pg_temp.id('sucursal'))
$$, 'producciones: la misma sucursal otra fecha sí');
select lives_ok($$
  insert into public.producciones (fecha, sucursal_id) values ('2187-03-10', pg_temp.id('otra_sucursal'))
$$, 'producciones: otra sucursal la misma fecha sí');

select throws_ok($$
  insert into public.detalle_ventas (nombre, precio, cantidad, total, ganancias, idtelas, idventa)
  values ('pgTAP lino', 10, 2, 20, 6, pg_temp.id('tela'), pg_temp.id('venta'))
$$, '23505', 'duplicate key value violates unique constraint "detalle_ventas_linea_key"',
'detalle_ventas: una línea por venta+tela+precio');
select lives_ok($$
  insert into public.detalle_ventas (nombre, precio, cantidad, total, ganancias, idtelas, idventa)
  values ('pgTAP lino', 12, 1, 12, 5, pg_temp.id('tela'), pg_temp.id('venta'))
$$, 'detalle_ventas: la misma tela a otro precio es otra línea');

select throws_ok($$
  insert into public.detalle_ventas_apliques (idventa, idapliques, idcolor, nombre, precio, cantidad, total, ganancias)
  values (pg_temp.id('venta_aplique'), pg_temp.id('aplique'), pg_temp.id('rojo'), 'pgTAP Mariposa', 10, 2, 20, 8)
$$, '23505', 'duplicate key value violates unique constraint "detalle_ventas_apliques_linea_key"',
'detalle_ventas_apliques: una línea por venta+aplique+color+precio');
select lives_ok($$
  insert into public.detalle_ventas_apliques (idventa, idapliques, idcolor, nombre, precio, cantidad, total, ganancias)
  values (pg_temp.id('venta_aplique'), pg_temp.id('aplique'), pg_temp.id('azul'), 'pgTAP Mariposa', 10, 1, 10, 4)
$$, 'detalle_ventas_apliques: otro color es otra línea');
select lives_ok($$
  insert into public.detalle_ventas_apliques (idventa, idapliques, idcolor, nombre, precio, cantidad, total, ganancias)
  values (pg_temp.id('venta_aplique'), pg_temp.id('aplique'), pg_temp.id('rojo'), 'pgTAP Mariposa', 12, 1, 12, 6)
$$, 'detalle_ventas_apliques: otro precio es otra línea');

select throws_ok($$
  insert into public.detalle_produccion (idproduccion, idaplique, idcolor, cantidad)
  values (pg_temp.id('produccion'), pg_temp.id('aplique'), pg_temp.id('rojo'), 3)
$$, '23505', 'duplicate key value violates unique constraint "detalle_produccion_linea_key"',
'detalle_produccion: una línea por producción+aplique+color');
select lives_ok($$
  insert into public.detalle_produccion (idproduccion, idaplique, idcolor, cantidad)
  values (pg_temp.id('produccion'), pg_temp.id('aplique'), pg_temp.id('azul'), 3)
$$, 'detalle_produccion: otro color es otra línea');

select throws_ok($$
  insert into public.inventario (sucursal_id, aplique_id, color_id, stock)
  values (pg_temp.id('sucursal'), pg_temp.id('aplique'), pg_temp.id('rojo'), 5)
$$, '23505', 'duplicate key value violates unique constraint "inventario_pkey"',
'inventario: una fila por sucursal+aplique+color');

select throws_ok($$
  insert into public.aplique_colores (idaplique, idcolor) values (pg_temp.id('aplique'), pg_temp.id('rojo'))
$$, '23505', 'duplicate key value violates unique constraint "aplique_colores_pkey"',
'aplique_colores: un vínculo por aplique+color');
select throws_ok($$
  insert into public.tela_colores (idtela, idcolor) values (pg_temp.id('tela'), pg_temp.id('rojo'))
$$, '23505', 'duplicate key value violates unique constraint "tela_colores_pkey"',
'tela_colores: un vínculo por tela+color');
select throws_ok($$
  insert into public.tela_sucursales (idtela, idsucursal) values (pg_temp.id('tela'), pg_temp.id('sucursal'))
$$, '23505', 'duplicate key value violates unique constraint "tela_sucursales_pkey"',
'tela_sucursales: un vínculo por tela+sucursal');

reset role;

select * from finish();
rollback;
