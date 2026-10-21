-- =====================================================================
-- RPC registrar_produccion (fabricación de apliques)
--
-- Migración 20261003000100_integridad_stock_y_ventas.sql (la clave
-- p_id_operacion de 20261020000000_idempotencia_y_venta_telas.sql se prueba
-- en 10_idempotencia.test.sql; acá todo va sin clave):
--   * una cabecera (producciones) por sucursal+fecha: la usa o la crea;
--   * upsert de líneas por (idproduccion, idaplique, idcolor): suma cantidad;
--   * suma la cantidad al stock de inventario (crea la fila o la reactiva);
--   * todo en una transacción: si una línea falla no queda nada.
--
-- Corre como authenticated (el rol de la app). Rollback al final.
-- =====================================================================
begin;
select plan(27);

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

-- Una línea como la manda ApliquesDatasourceImpl.createProduccion
create function pg_temp.linea(p_aplique text, p_color text, p_cantidad numeric)
  returns jsonb
  language sql stable
  as $$
  select jsonb_build_object(
    'idaplique', pg_temp.id(p_aplique),
    'idcolor',   pg_temp.id(p_color),
    'cantidad',  p_cantidad)
$$;

create function pg_temp.fabricar(p_sucursal text, p_fecha date, variadic p_lineas jsonb[])
  returns bigint
  language sql
  as $$ select public.registrar_produccion(pg_temp.id(p_sucursal), p_fecha, to_jsonb(p_lineas)) $$;

create function pg_temp.stock(p_aplique text, p_color text, p_sucursal text default 'sucursal')
  returns numeric
  language sql stable
  as $$
  select stock from public.inventario
  where sucursal_id = pg_temp.id(p_sucursal)
    and aplique_id = pg_temp.id(p_aplique)
    and color_id = pg_temp.id(p_color)
$$;

-- Todo lo que una producción puede tocar en las sucursales del test
create function pg_temp.estado() returns jsonb
  language sql stable
  as $$
  select jsonb_build_object(
    'producciones', (
      select coalesce(jsonb_agg(to_jsonb(p) order by p.id), '[]')
      from public.producciones p
      where p.sucursal_id in (pg_temp.id('sucursal'), pg_temp.id('otra_sucursal'))),
    'lineas', (
      select coalesce(jsonb_agg(to_jsonb(d) order by d.id), '[]')
      from public.detalle_produccion d
      join public.producciones p on p.id = d.idproduccion
      where p.sucursal_id in (pg_temp.id('sucursal'), pg_temp.id('otra_sucursal'))),
    'inventario', (
      select coalesce(jsonb_agg(to_jsonb(i) order by i.sucursal_id, i.aplique_id, i.color_id), '[]')
      from public.inventario i
      where i.sucursal_id in (pg_temp.id('sucursal'), pg_temp.id('otra_sucursal'))))
$$;

--   mariposa/rojo: sin fila de inventario
--   mariposa/azul: fila dada de baja (activo = false, stock 0)
do $$
declare
  v_suc bigint; v_otra bigint; v_rojo bigint; v_azul bigint; v_mariposa bigint;
begin
  insert into public.sucursales (nombre) values ('pgTAP sucursal') returning id into v_suc;
  insert into public.sucursales (nombre) values ('pgTAP otra sucursal') returning id into v_otra;
  insert into public.colores (nombre) values ('pgTAP rojo') returning id into v_rojo;
  insert into public.colores (nombre) values ('pgTAP azul') returning id into v_azul;
  insert into public.apliques (nombre, costo_fabricacion) values ('pgTAP Mariposa', 6) returning id into v_mariposa;
  insert into public.aplique_colores (idaplique, idcolor) values (v_mariposa, v_rojo), (v_mariposa, v_azul);
  insert into public.inventario (sucursal_id, aplique_id, color_id, stock, activo)
    values (v_suc, v_mariposa, v_azul, 0, false);

  insert into pg_temp._ids values
    ('sucursal', v_suc), ('otra_sucursal', v_otra),
    ('rojo', v_rojo), ('azul', v_azul), ('mariposa', v_mariposa);
end
$$;

set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-0000000000a3", "role": "authenticated"}';

-- =====================================================================
-- Firma
-- =====================================================================
select function_returns(
  'public', 'registrar_produccion', array['bigint', 'date', 'jsonb', 'uuid'], 'bigint',
  'registrar_produccion(bigint, date, jsonb, uuid) devuelve el id de la producción'
);

-- =====================================================================
-- Primera fabricación del día: cabecera, línea y fila de inventario nueva
-- =====================================================================
select lives_ok($$
  insert into pg_temp._ids
  select 'prod_10', pg_temp.fabricar('sucursal', '2187-03-10', pg_temp.linea('mariposa', 'rojo', 5))
$$, 'authenticated registra una fabricación');

select results_eq(
  $$ select fecha, sucursal_id from public.producciones where sucursal_id = pg_temp.id('sucursal') $$,
  $$ values ('2187-03-10'::date, pg_temp.id('sucursal')) $$,
  'crea la producción (cabecera) de la sucursal en esa fecha'
);

select results_eq(
  $$ select idaplique, idcolor, cantidad from public.detalle_produccion where idproduccion = pg_temp.id('prod_10') $$,
  $$ values (pg_temp.id('mariposa'), pg_temp.id('rojo'), 5::numeric) $$,
  'guarda la línea aplique+color+cantidad'
);

select results_eq($$
  select stock, activo from public.inventario
  where sucursal_id = pg_temp.id('sucursal') and aplique_id = pg_temp.id('mariposa') and color_id = pg_temp.id('rojo')
$$, $$ values (5::numeric, true) $$,
'crea la fila de inventario que no existía, con el stock fabricado');

-- =====================================================================
-- Otra fabricación el mismo día: misma cabecera, líneas acumuladas
-- =====================================================================
select lives_ok($$
  insert into pg_temp._ids
  select 'prod_10_tarde', pg_temp.fabricar('sucursal', '2187-03-10',
    pg_temp.linea('mariposa', 'rojo', 3),
    pg_temp.linea('mariposa', 'azul', 4))
$$, 'registra otra fabricación el mismo día');

select is(pg_temp.id('prod_10_tarde'), pg_temp.id('prod_10'),
  'devuelve la producción del día');

select results_eq(
  $$ select count(*) from public.producciones where sucursal_id = pg_temp.id('sucursal') and fecha = '2187-03-10' $$,
  array[1::bigint],
  'sigue habiendo una sola producción para la sucursal ese día'
);

select results_eq($$
  select idcolor, cantidad from public.detalle_produccion
  where idproduccion = pg_temp.id('prod_10') order by cantidad desc
$$, $$ values (pg_temp.id('rojo'), 8::numeric), (pg_temp.id('azul'), 4::numeric) $$,
'el mismo aplique+color suma a su línea; otro color es otra línea');

select results_eq($$
  select stock, activo from public.inventario
  where sucursal_id = pg_temp.id('sucursal') and aplique_id = pg_temp.id('mariposa') and color_id = pg_temp.id('rojo')
$$, $$ values (8::numeric, true) $$,
'suma la cantidad al stock existente');

select results_eq($$
  select stock, activo from public.inventario
  where sucursal_id = pg_temp.id('sucursal') and aplique_id = pg_temp.id('mariposa') and color_id = pg_temp.id('azul')
$$, $$ values (4::numeric, true) $$,
'reactiva la fila de inventario dada de baja y le suma lo fabricado');

-- La misma línea dos veces en un registro
select lives_ok($$
  select pg_temp.fabricar('sucursal', '2187-03-10',
    pg_temp.linea('mariposa', 'rojo', 1),
    pg_temp.linea('mariposa', 'rojo', 1))
$$, 'registra una fabricación con la misma línea repetida');

select results_eq($$
  select count(*), sum(cantidad) from public.detalle_produccion
  where idproduccion = pg_temp.id('prod_10') and idcolor = pg_temp.id('rojo')
$$, $$ values (1::bigint, 10::numeric) $$,
'las líneas repetidas quedan en una sola');

select is(pg_temp.stock('mariposa', 'rojo'), 10::numeric,
  'y suman las dos al stock');

-- =====================================================================
-- Otra fecha / otra sucursal: otra cabecera
-- =====================================================================
select lives_ok($$
  insert into pg_temp._ids
  select 'prod_11', pg_temp.fabricar('sucursal', '2187-03-11', pg_temp.linea('mariposa', 'rojo', 2))
$$, 'registra una fabricación en otra fecha');

select isnt(pg_temp.id('prod_11'), pg_temp.id('prod_10'),
  'otra fecha es otra producción');

select is(pg_temp.stock('mariposa', 'rojo'), 12::numeric,
  'el stock sigue sumando entre días');

select lives_ok($$
  insert into pg_temp._ids
  select 'prod_otra', pg_temp.fabricar('otra_sucursal', '2187-03-10', pg_temp.linea('mariposa', 'rojo', 7))
$$, 'registra una fabricación en otra sucursal la misma fecha');

select isnt(pg_temp.id('prod_otra'), pg_temp.id('prod_10'),
  'la misma fecha en otra sucursal es otra producción');

select results_eq(
  $$ select pg_temp.stock('mariposa', 'rojo'), pg_temp.stock('mariposa', 'rojo', 'otra_sucursal') $$,
  $$ values (12::numeric, 7::numeric) $$,
  'el stock es de cada sucursal'
);

-- =====================================================================
-- Fallas: la fabricación entera se rechaza y no deja nada
-- =====================================================================
insert into pg_temp._estado values ('antes_de_fallar', pg_temp.estado());

select throws_ok($$
  select pg_temp.fabricar('sucursal', '2187-03-12',
    pg_temp.linea('mariposa', 'rojo', 2),
    pg_temp.linea('mariposa', 'azul', 0))
$$, '23514',
'new row for relation "detalle_produccion" violates check constraint "detalle_produccion_cantidad_check"',
'rechaza una cantidad 0');

select is_empty(
  $$ select 1 from public.producciones where sucursal_id = pg_temp.id('sucursal') and fecha = '2187-03-12' $$,
  'la fabricación rechazada no deja la cabecera del día'
);

-- Caería sobre la línea del día (rojo tiene 10): no puede restar stock
select throws_ok($$
  select pg_temp.fabricar('sucursal', '2187-03-10', pg_temp.linea('mariposa', 'rojo', -5))
$$, '23514',
'new row for relation "detalle_produccion" violates check constraint "detalle_produccion_cantidad_check"',
'rechaza una cantidad negativa aunque caiga sobre una línea existente');

select throws_ok($$
  select public.registrar_produccion(pg_temp.id('sucursal'), '2187-03-12',
    jsonb_build_array(
      pg_temp.linea('mariposa', 'rojo', 2),
      jsonb_build_object('idaplique', -1, 'idcolor', pg_temp.id('rojo'), 'cantidad', 1)))
$$, '23503', null,
'rechaza un aplique que no existe');

select is(pg_temp.estado(), (select valor from pg_temp._estado where clave = 'antes_de_fallar'),
  'ninguna fabricación rechazada dejó cabecera, líneas ni stock (tampoco las líneas válidas que venían antes)');

-- Va al final: mientras el bug exista, las llamadas SÍ escriben
select todo('bug (menor): 20261020000000_idempotencia_y_venta_telas.sql:213 — registrar_produccion no valida p_lineas: con [] o NULL crea una producción del día vacía (crear_venta_apliques sí rechaza una venta sin líneas)', 2);
select throws_ok($$
  select public.registrar_produccion(pg_temp.id('sucursal'), '2187-03-13', '[]'::jsonb)
$$, null::char(5), null,
'rechaza una fabricación sin líneas');
select throws_ok($$
  select public.registrar_produccion(pg_temp.id('sucursal'), '2187-03-14', null)
$$, null::char(5), null,
'rechaza p_lineas NULL');

reset role;

select * from finish();
rollback;
