-- =====================================================================
-- RPC crear_venta_apliques (venta de apliques)
--
-- Última versión: 20261007000000_venta_apliques_colores_vinculados.sql.
--   * una venta por sucursal+día: la crea o le suma total/ganancias/descuento
--     (la fecha queda la del primer registro del día);
--   * acumula líneas por (aplique, color, precio);
--   * descuenta el stock de inventario (activo) de esa sucursal;
--   * falla ENTERA, sin efectos parciales, si una línea no tiene stock, no
--     está en inventario activo, o su color no está vinculado al aplique
--     (aplique_colores activo) — HINT stock_insuficiente / color_no_vinculado.
--
-- Corre como authenticated (el rol de la app). Rollback al final.
-- =====================================================================
begin;
select plan(40);

-- ---------------------------------------------------------------------
-- Datos de apoyo (solo viven en esta transacción)
-- ---------------------------------------------------------------------
create temp table _ids (clave text primary key, id bigint not null) on commit drop;
grant all on _ids to public;
create function pg_temp.id(p_clave text) returns bigint
  language sql stable
  as $$ select id from pg_temp._ids where clave = p_clave $$;

create temp table _estado (clave text primary key, valor jsonb) on commit drop;
grant all on _estado to public;

-- SQLSTATE, mensaje y HINT del error que tira una sentencia (o NULL)
create function pg_temp.error_de(p_sql text) returns jsonb
  language plpgsql
  as $$
declare
  v_estado text; v_mensaje text; v_hint text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_estado = returned_sqlstate, v_mensaje = message_text, v_hint = pg_exception_hint;
  return jsonb_build_object('sqlstate', v_estado, 'mensaje', v_mensaje, 'hint', v_hint);
end
$$;

-- Una línea como la manda la app (costo de fabricación 6 → ganancia = precio - 6)
create function pg_temp.linea(p_aplique text, p_color text, p_precio numeric, p_cantidad numeric)
  returns jsonb
  language sql stable
  as $$
  select jsonb_build_object(
    'idapliques', pg_temp.id(p_aplique),
    'idcolor',    pg_temp.id(p_color),
    'nombre',     format('pgTAP %s %s', p_aplique, p_color),
    'precio',     p_precio,
    'cantidad',   p_cantidad,
    'total',      p_precio * p_cantidad,
    'ganancias',  (p_precio - 6) * p_cantidad)
$$;

-- Llama a la RPC como VentaApliquesFormCubit: total = líneas - descuento,
-- ganancias = suma de las líneas
create function pg_temp.vender(p_sucursal text, p_fecha text, p_descuento numeric, variadic p_lineas jsonb[])
  returns bigint
  language sql
  as $$
  select public.crear_venta_apliques(
    pg_temp.id(p_sucursal),
    p_fecha,
    (select sum((l->>'total')::numeric) from unnest(p_lineas) l) - p_descuento,
    (select sum((l->>'ganancias')::numeric) from unnest(p_lineas) l),
    p_descuento,
    to_jsonb(p_lineas))
$$;

create function pg_temp.stock(p_aplique text, p_color text, p_sucursal text default 'sucursal')
  returns numeric
  language sql stable
  as $$
  select stock from public.inventario
  where sucursal_id = pg_temp.id(p_sucursal)
    and aplique_id = pg_temp.id(p_aplique)
    and color_id = pg_temp.id(p_color)
$$;

-- Todo lo que una venta puede tocar en las sucursales del test
create function pg_temp.estado() returns jsonb
  language sql stable
  as $$
  select jsonb_build_object(
    'ventas', (
      select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]')
      from public.ventas_apliques v
      where v.idsucursales in (pg_temp.id('sucursal'), pg_temp.id('otra_sucursal'))),
    'lineas', (
      select coalesce(jsonb_agg(to_jsonb(d) order by d.id), '[]')
      from public.detalle_ventas_apliques d
      join public.ventas_apliques v on v.id = d.idventa
      where v.idsucursales in (pg_temp.id('sucursal'), pg_temp.id('otra_sucursal'))),
    'inventario', (
      select coalesce(jsonb_agg(to_jsonb(i) order by i.sucursal_id, i.aplique_id, i.color_id), '[]')
      from public.inventario i
      where i.sucursal_id in (pg_temp.id('sucursal'), pg_temp.id('otra_sucursal'))))
$$;

--   mariposa: rojo (stock 10), azul (stock 2), verde (stock 5 pero color
--             deshabilitado en aplique_colores)
--   corazon:  rojo (stock 4 pero fila de inventario dada de baja),
--             azul (vinculado, sin fila de inventario), verde (nunca vinculado)
--   otra_sucursal: sin inventario
do $$
declare
  v_suc bigint; v_otra bigint; v_rojo bigint; v_azul bigint; v_verde bigint;
  v_mariposa bigint; v_corazon bigint;
begin
  insert into public.sucursales (nombre) values ('pgTAP sucursal') returning id into v_suc;
  insert into public.sucursales (nombre) values ('pgTAP otra sucursal') returning id into v_otra;
  insert into public.colores (nombre) values ('pgTAP rojo') returning id into v_rojo;
  insert into public.colores (nombre) values ('pgTAP azul') returning id into v_azul;
  insert into public.colores (nombre) values ('pgTAP verde') returning id into v_verde;
  insert into public.apliques (nombre, costo_fabricacion) values ('pgTAP Mariposa', 6) returning id into v_mariposa;
  insert into public.apliques (nombre, costo_fabricacion) values ('pgTAP Corazón', 6) returning id into v_corazon;

  insert into public.aplique_colores (idaplique, idcolor, activo) values
    (v_mariposa, v_rojo, true), (v_mariposa, v_azul, true), (v_mariposa, v_verde, false),
    (v_corazon, v_rojo, true), (v_corazon, v_azul, true);

  insert into public.inventario (sucursal_id, aplique_id, color_id, stock, activo) values
    (v_suc, v_mariposa, v_rojo, 10, true),
    (v_suc, v_mariposa, v_azul, 2, true),
    (v_suc, v_mariposa, v_verde, 5, true),
    (v_suc, v_corazon, v_rojo, 4, false);

  insert into pg_temp._ids values
    ('sucursal', v_suc), ('otra_sucursal', v_otra),
    ('rojo', v_rojo), ('azul', v_azul), ('verde', v_verde),
    ('mariposa', v_mariposa), ('corazon', v_corazon);
end
$$;

set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-0000000000a2", "role": "authenticated"}';

-- =====================================================================
-- Firma (la llaman Flutter e iOS: no puede cambiar)
-- =====================================================================
select function_returns(
  'public', 'crear_venta_apliques',
  array['bigint', 'text', 'numeric', 'numeric', 'numeric', 'jsonb'], 'bigint',
  'crear_venta_apliques(bigint, text, numeric, numeric, numeric, jsonb) devuelve el id de la venta'
);

-- =====================================================================
-- Primera venta del día: crea la cabecera, las líneas y descuenta stock
-- =====================================================================
select lives_ok($$
  insert into pg_temp._ids
  select 'venta_10', pg_temp.vender('sucursal', '2187-03-10T09:15:00.000', 2,
    pg_temp.linea('mariposa', 'rojo', 10, 2),
    pg_temp.linea('mariposa', 'azul', 10, 1))
$$, 'authenticated registra una venta de apliques');

select results_eq($$
  select fecha, total, ganancias, descuento
  from public.ventas_apliques where idsucursales = pg_temp.id('sucursal')
$$, $$ values ('2187-03-10T09:15:00.000', 28::numeric, 12::numeric, 2::numeric) $$,
'crea la venta del día con total, ganancias y descuento');

select results_eq($$
  select idapliques, idcolor, precio, cantidad, total, ganancias
  from public.detalle_ventas_apliques where idventa = pg_temp.id('venta_10')
  order by total desc
$$, $$ values
  (pg_temp.id('mariposa'), pg_temp.id('rojo'), 10::numeric, 2::numeric, 20::numeric, 8::numeric),
  (pg_temp.id('mariposa'), pg_temp.id('azul'), 10::numeric, 1::numeric, 10::numeric, 4::numeric)
$$, 'guarda una línea por aplique+color+precio');

select results_eq(
  $$ select pg_temp.stock('mariposa', 'rojo'), pg_temp.stock('mariposa', 'azul') $$,
  $$ values (8::numeric, 1::numeric) $$,
  'descuenta el stock de cada aplique+color'
);

-- =====================================================================
-- Segunda venta del mismo día: se suma a la venta del día
-- =====================================================================
select lives_ok($$
  insert into pg_temp._ids
  select 'venta_10_tarde', pg_temp.vender('sucursal', '2187-03-10T17:40:00.000', 2,
    pg_temp.linea('mariposa', 'rojo', 10, 3),
    pg_temp.linea('mariposa', 'rojo', 12, 1))
$$, 'registra otra venta el mismo día');

select is(pg_temp.id('venta_10_tarde'), pg_temp.id('venta_10'),
  'devuelve la misma venta del día');

select results_eq($$
  select fecha, total, ganancias, descuento
  from public.ventas_apliques where idsucursales = pg_temp.id('sucursal')
$$, $$ values ('2187-03-10T09:15:00.000', 68::numeric, 30::numeric, 4::numeric) $$,
'sigue habiendo una sola venta ese día: suma total, ganancias y descuento y conserva la fecha del primer registro');

select results_eq($$
  select idcolor, precio, cantidad, total, ganancias
  from public.detalle_ventas_apliques where idventa = pg_temp.id('venta_10')
  order by total desc
$$, $$ values
  (pg_temp.id('rojo'), 10::numeric, 5::numeric, 50::numeric, 20::numeric),
  (pg_temp.id('rojo'), 12::numeric, 1::numeric, 12::numeric,  6::numeric),
  (pg_temp.id('azul'), 10::numeric, 1::numeric, 10::numeric,  4::numeric)
$$, 'la misma línea (aplique+color+precio) acumula; otro precio es otra línea');

select is(pg_temp.stock('mariposa', 'rojo'), 4::numeric,
  'descuenta el stock de las dos líneas');

-- =====================================================================
-- Otro día: otra venta. La misma línea repetida en un registro se acumula
-- =====================================================================
select lives_ok($$
  insert into pg_temp._ids
  select 'venta_11', pg_temp.vender('sucursal', '2187-03-11T10:00:00.000', 0,
    pg_temp.linea('mariposa', 'rojo', 10, 1),
    pg_temp.linea('mariposa', 'rojo', 10, 1))
$$, 'registra una venta en otro día');

select isnt(pg_temp.id('venta_11'), pg_temp.id('venta_10'),
  'otro día crea otra venta');

select results_eq($$
  select idcolor, precio, cantidad, total, ganancias
  from public.detalle_ventas_apliques where idventa = pg_temp.id('venta_11')
$$, $$ values (pg_temp.id('rojo'), 10::numeric, 2::numeric, 20::numeric, 8::numeric) $$,
'dos líneas iguales en el mismo registro quedan como una sola');

select is(pg_temp.stock('mariposa', 'rojo'), 2::numeric,
  'descuenta el stock de ambas');

select results_eq(
  $$ select count(*) from public.ventas_apliques where idsucursales = pg_temp.id('sucursal') $$,
  array[2::bigint],
  'hay una venta por día'
);

-- Vender exactamente lo que hay deja el stock en 0
select lives_ok($$
  select pg_temp.vender('sucursal', '2187-03-11T11:00:00.000', 0,
    pg_temp.linea('mariposa', 'azul', 10, 1))
$$, 'se puede vender todo el stock que queda');

select is(pg_temp.stock('mariposa', 'azul'), 0::numeric,
  'el stock queda en 0');

-- =====================================================================
-- Fallas: la venta entera se rechaza y no deja nada
-- (rojo tiene 2, azul 0)
-- =====================================================================
insert into pg_temp._estado values ('antes_de_fallar', pg_temp.estado());

-- Sin stock, en un día sin venta
select throws_ok($$
  select pg_temp.vender('sucursal', '2187-03-12T10:00:00.000', 0,
    pg_temp.linea('mariposa', 'rojo', 10, 1),
    pg_temp.linea('mariposa', 'azul', 10, 1))
$$, 'P0001', 'Stock insuficiente: pgTAP mariposa azul',
'falla si una línea no tiene stock suficiente');

select is(
  pg_temp.error_de($$
    select pg_temp.vender('sucursal', '2187-03-12T10:00:00.000', 0,
      pg_temp.linea('mariposa', 'azul', 10, 1))
  $$)->>'hint',
  'stock_insuficiente',
  'el error de stock lleva HINT stock_insuficiente'
);

select is_empty($$
  select 1 from public.ventas_apliques
  where idsucursales = pg_temp.id('sucursal') and fecha like '2187-03-12%'
$$, 'la venta fallida no crea la venta del día');

select is(pg_temp.estado(), (select valor from pg_temp._estado where clave = 'antes_de_fallar'),
  'la venta fallida no deja líneas ni descuenta el stock de la línea que sí tenía');

-- Sin stock, en un día que ya tiene venta (la primera línea se acumularía)
select throws_ok($$
  select pg_temp.vender('sucursal', '2187-03-10T19:00:00.000', 0,
    pg_temp.linea('mariposa', 'rojo', 10, 1),
    pg_temp.linea('mariposa', 'rojo', 10, 5))
$$, 'P0001', 'Stock insuficiente: pgTAP mariposa rojo',
'falla si el total pedido de un aplique+color supera el stock');

select is(pg_temp.estado(), (select valor from pg_temp._estado where clave = 'antes_de_fallar'),
  'la venta del día no suma totales ni líneas y el stock no se mueve');

-- Fila de inventario dada de baja
select throws_ok($$
  select pg_temp.vender('sucursal', '2187-03-10T19:00:00.000', 0,
    pg_temp.linea('corazon', 'rojo', 15, 1))
$$, 'P0001', 'Stock insuficiente: pgTAP corazon rojo',
'falla si la fila de inventario está dada de baja (aunque tenga stock)');

select is(
  pg_temp.error_de($$
    select pg_temp.vender('sucursal', '2187-03-10T19:00:00.000', 0,
      pg_temp.linea('corazon', 'rojo', 15, 1))
  $$)->>'hint',
  'stock_insuficiente',
  'inventario inactivo → HINT stock_insuficiente'
);

-- Sin fila de inventario
select throws_ok($$
  select pg_temp.vender('sucursal', '2187-03-10T19:00:00.000', 0,
    pg_temp.linea('corazon', 'azul', 15, 1))
$$, 'P0001', 'Stock insuficiente: pgTAP corazon azul',
'falla si el aplique+color no está en el inventario de la sucursal');

select is(
  pg_temp.error_de($$
    select pg_temp.vender('sucursal', '2187-03-10T19:00:00.000', 0,
      pg_temp.linea('corazon', 'azul', 15, 1))
  $$)->>'hint',
  'stock_insuficiente',
  'sin inventario → HINT stock_insuficiente'
);

-- El stock es de cada sucursal
select throws_ok($$
  select pg_temp.vender('otra_sucursal', '2187-03-10T19:00:00.000', 0,
    pg_temp.linea('mariposa', 'rojo', 10, 1))
$$, 'P0001', 'Stock insuficiente: pgTAP mariposa rojo',
'el stock de una sucursal no sirve para vender en otra');

-- Color deshabilitado para el aplique (con stock)
select throws_ok($$
  select pg_temp.vender('sucursal', '2187-03-10T19:30:00.000', 0,
    pg_temp.linea('mariposa', 'rojo', 10, 1),
    pg_temp.linea('mariposa', 'verde', 10, 1))
$$, 'P0001', 'Color no habilitado para el aplique: pgTAP mariposa verde',
'falla si el color está deshabilitado en aplique_colores aunque haya stock');

select is(
  pg_temp.error_de($$
    select pg_temp.vender('sucursal', '2187-03-10T19:30:00.000', 0,
      pg_temp.linea('mariposa', 'verde', 10, 1))
  $$)->>'hint',
  'color_no_vinculado',
  'color deshabilitado → HINT color_no_vinculado'
);

-- Color nunca vinculado al aplique
select throws_ok($$
  select pg_temp.vender('sucursal', '2187-03-10T19:30:00.000', 0,
    pg_temp.linea('corazon', 'verde', 15, 1))
$$, 'P0001', 'Color no habilitado para el aplique: pgTAP corazon verde',
'falla si el color nunca se vinculó al aplique');

select is(
  pg_temp.error_de($$
    select pg_temp.vender('sucursal', '2187-03-10T19:30:00.000', 0,
      pg_temp.linea('corazon', 'verde', 15, 1))
  $$)->>'hint',
  'color_no_vinculado',
  'color no vinculado → HINT color_no_vinculado'
);

select is(pg_temp.stock('mariposa', 'verde'), 5::numeric,
  'el stock del color deshabilitado no se toca');

select is(pg_temp.estado(), (select valor from pg_temp._estado where clave = 'antes_de_fallar'),
  'ninguna de las ventas rechazadas dejó cabecera, líneas ni movimiento de stock');

-- =====================================================================
-- Entradas inválidas
-- =====================================================================
select throws_ok($$
  select public.crear_venta_apliques(pg_temp.id('sucursal'), '2187-03-13T10:00:00.000', 0, 0, 0, '[]'::jsonb)
$$, 'P0001', 'La venta no tiene líneas',
'rechaza una venta sin líneas');

select throws_ok($$
  select public.crear_venta_apliques(pg_temp.id('sucursal'), '2187-03-13T10:00:00.000', 0, 0, 0, '{}'::jsonb)
$$, 'P0001', 'La venta no tiene líneas',
'rechaza p_detalles que no es un arreglo');

-- Una cantidad negativa que se acumularía sobre la línea del día (rojo a 10
-- tiene 5) no puede devolver stock: el CHECK mira la fila propuesta.
-- (Total de cabecera 0 para que sea la línea, no la cabecera, la que falle.)
select throws_ok($$
  select public.crear_venta_apliques(pg_temp.id('sucursal'), '2187-03-10T20:00:00.000', 0, 0, 0,
    jsonb_build_array(pg_temp.linea('mariposa', 'rojo', 10, -3)))
$$, '23514',
'new row for relation "detalle_ventas_apliques" violates check constraint "detalle_ventas_apliques_montos_check"',
'rechaza una cantidad negativa aunque caiga sobre una línea existente');

select throws_ok($$
  select public.crear_venta_apliques(pg_temp.id('sucursal'), '2187-03-10T20:00:00.000', 0, 0, 0,
    jsonb_build_array(pg_temp.linea('mariposa', 'rojo', 10, 0)))
$$, '23514',
'new row for relation "detalle_ventas_apliques" violates check constraint "detalle_ventas_apliques_montos_check"',
'rechaza una cantidad 0');

select is(pg_temp.estado(), (select valor from pg_temp._estado where clave = 'antes_de_fallar'),
  'las entradas inválidas no dejaron nada');

-- Va al final: mientras el bug exista, la llamada SÍ escribe
select todo('bug: 20261007000000_venta_apliques_colores_vinculados.sql:33 — con p_detalles NULL el IF da NULL (no TRUE) y no corta: crea o le suma total/ganancias/descuento a la venta del día sin ninguna línea ni movimiento de stock', 1);
select throws_ok($$
  select public.crear_venta_apliques(pg_temp.id('sucursal'), '2187-03-14T10:00:00.000', 5, 1, 0, null)
$$, 'P0001', 'La venta no tiene líneas',
'rechaza p_detalles NULL');

reset role;

select * from finish();
rollback;
