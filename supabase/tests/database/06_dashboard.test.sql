-- =====================================================================
-- RPC del dashboard: top_productos, top_apliques, resumen_ventas,
-- resumen_ventas_apliques
--
--   * filtran por rango comparando fecha como TEXTO ISO8601 (por eso la app
--     manda hasta = '…T23:59:59.999999');
--   * top_productos agrupa por idtelas y top_apliques por idapliques, con el
--     nombre actual de la tabla (no el de la línea); suman total y cantidad;
--   * resumen_* suman total/ganancias/descuento de las cabeceras (0 si no hay).
--
-- Los datos van en 2187 para no mezclarse con ventas reales. Corre como
-- authenticated. Rollback al final.
-- =====================================================================
begin;
select plan(17);

-- ---------------------------------------------------------------------
-- Datos de apoyo (solo viven en esta transacción)
-- ---------------------------------------------------------------------
create temp table _ids (clave text primary key, id bigint not null) on commit drop;
grant all on _ids to public;
create function pg_temp.id(p_clave text) returns bigint
  language sql stable
  as $$ select id from pg_temp._ids where clave = p_clave $$;

do $$
declare
  v_s1 bigint; v_s2 bigint; v_lino bigint; v_seda bigint;
  v_rojo bigint; v_azul bigint; v_mariposa bigint; v_corazon bigint;
  v1 bigint; v2 bigint; v3 bigint; v4 bigint;
  va0 bigint; va1 bigint; va2 bigint; va3 bigint;
begin
  insert into public.sucursales (nombre) values ('pgTAP sucursal 1') returning id into v_s1;
  insert into public.sucursales (nombre) values ('pgTAP sucursal 2') returning id into v_s2;
  insert into public.telas (nombre, precxmen) values ('pgTAP Lino', 10) returning id into v_lino;
  insert into public.telas (nombre, precxmen) values ('pgTAP Seda', 20) returning id into v_seda;
  insert into public.colores (nombre) values ('pgTAP rojo') returning id into v_rojo;
  insert into public.colores (nombre) values ('pgTAP azul') returning id into v_azul;
  insert into public.apliques (nombre) values ('pgTAP Mariposa') returning id into v_mariposa;
  insert into public.apliques (nombre) values ('pgTAP Corazón') returning id into v_corazon;

  -- Ventas de telas: v1 y v2 en marzo (en los bordes del mes), v3 y v4 afuera
  insert into public.ventas (fecha, total, ganancias, descuento, idsucursales)
    values ('2187-03-01T00:00:00.000', 100, 30, 5, v_s1) returning id into v1;
  insert into public.ventas (fecha, total, ganancias, descuento, idsucursales)
    values ('2187-03-31T23:59:59.500', 200, 50, 0, v_s2) returning id into v2;
  insert into public.ventas (fecha, total, ganancias, descuento, idsucursales)
    values ('2187-02-28T23:59:59.999', 1000, 1, 1, v_s1) returning id into v3;
  insert into public.ventas (fecha, total, ganancias, descuento, idsucursales)
    values ('2187-04-01T00:00:00.000', 2000, 2, 2, v_s1) returning id into v4;

  -- El nombre de la línea no importa: se agrupa por idtelas
  insert into public.detalle_ventas (nombre, precio, cantidad, total, ganancias, idtelas, idventa) values
    ('Lino viejo',     10,   3,   30,  9, v_lino, v1),
    ('pgTAP Seda',     20,   2,   40, 12, v_seda, v1),
    ('cualquier cosa', 10,   5,   50, 15, v_lino, v2),
    ('x',              12,   1,   12,  5, v_lino, v2),
    ('Seda',           20, 100, 2000,  1, v_seda, v3),
    ('Lino',           10, 100, 1000,  2, v_lino, v4);

  -- Ventas de apliques: va1 y va2 en marzo, va0 y va3 afuera
  insert into public.ventas_apliques (fecha, total, ganancias, descuento, idsucursales)
    values ('2187-02-15T10:00:00.000', 7, 7, 7, v_s2) returning id into va0;
  insert into public.ventas_apliques (fecha, total, ganancias, descuento, idsucursales)
    values ('2187-03-05T10:00:00.000', 60, 20, 3, v_s1) returning id into va1;
  insert into public.ventas_apliques (fecha, total, ganancias, descuento, idsucursales)
    values ('2187-03-20T15:00:00.000', 45, 15, 0, v_s2) returning id into va2;
  insert into public.ventas_apliques (fecha, total, ganancias, descuento, idsucursales)
    values ('2187-04-02T10:00:00.000', 999, 9, 9, v_s1) returning id into va3;

  -- detalle_ventas_apliques.nombre trae basura ("A"): se usa el de apliques
  insert into public.detalle_ventas_apliques (idventa, idapliques, idcolor, nombre, precio, cantidad, total, ganancias) values
    (va1, v_mariposa, v_rojo, 'A',        10,  2,   20,  8),
    (va1, v_mariposa, v_azul, 'A',        10,  1,   10,  4),
    (va1, v_corazon,  v_rojo, 'Corazon',  15,  2,   30,  8),
    (va2, v_mariposa, v_rojo, 'Mariposa', 15,  3,   45, 15),
    (va0, v_mariposa, v_azul, 'x',         7,  1,    7,  1),
    (va3, v_corazon,  v_rojo, 'x',        20, 50, 1000,  9);

  insert into pg_temp._ids values
    ('lino', v_lino), ('seda', v_seda), ('mariposa', v_mariposa), ('corazon', v_corazon);
end
$$;

set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-0000000000a6", "role": "authenticated"}';

-- =====================================================================
-- Firmas (la app mapea estas columnas: no pueden cambiar)
-- =====================================================================
select is(
  pg_get_function_result('public.top_productos(text,text)'::regprocedure),
  'TABLE(nombre text, total_vendido numeric, total_cantidad numeric)',
  'top_productos(desde text, hasta text) devuelve nombre, total_vendido, total_cantidad'
);
select is(
  pg_get_function_result('public.top_apliques(text,text)'::regprocedure),
  'TABLE(nombre text, total_vendido numeric, total_cantidad numeric)',
  'top_apliques(desde text, hasta text) devuelve las mismas columnas que top_productos'
);
select is(
  pg_get_function_result('public.resumen_ventas(text,text)'::regprocedure),
  'TABLE(total numeric, ganancias numeric, descuento numeric)',
  'resumen_ventas(desde text, hasta text) devuelve total, ganancias, descuento'
);
select is(
  pg_get_function_result('public.resumen_ventas_apliques(text,text)'::regprocedure),
  'TABLE(total numeric, ganancias numeric, descuento numeric)',
  'resumen_ventas_apliques(desde text, hasta text) devuelve total, ganancias, descuento'
);
select is_empty($$
  select proname from pg_proc
  where pronamespace = 'public'::regnamespace
    and proname in ('top_productos', 'top_apliques', 'resumen_ventas', 'resumen_ventas_apliques')
    and provolatile <> 's'
$$, 'las cuatro RPC del dashboard son STABLE (solo leen)');

-- =====================================================================
-- Telas
-- =====================================================================
select results_eq($$
  select * from public.top_productos('2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999')
$$, $$ values
  ('pgTAP Lino', 92::numeric, 9::numeric),
  ('pgTAP Seda', 40::numeric, 2::numeric)
$$, 'top_productos: agrupa por tela con su nombre actual, suma total y cantidad del rango y ordena por total');

select is_empty(
  $$ select * from public.top_productos('2187-05-01T00:00:00.000', '2187-05-31T23:59:59.999999') $$,
  'top_productos: sin ventas en el rango no devuelve filas'
);

select results_eq($$
  select * from public.top_productos('2187-03-01T00:00:00.000', '2187-03-31T23:59:59')
$$, $$ values
  ('pgTAP Seda', 40::numeric, 2::numeric),
  ('pgTAP Lino', 30::numeric, 3::numeric)
$$, 'top_productos: compara fecha como texto ("…T23:59:59" deja afuera "…T23:59:59.500")');

select results_eq(
  $$ select * from public.resumen_ventas('2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999') $$,
  $$ values (300::numeric, 80::numeric, 5::numeric) $$,
  'resumen_ventas: suma total, ganancias y descuento de las ventas del rango'
);

select results_eq(
  $$ select * from public.resumen_ventas('2187-05-01T00:00:00.000', '2187-05-31T23:59:59.999999') $$,
  $$ values (0::numeric, 0::numeric, 0::numeric) $$,
  'resumen_ventas: sin ventas devuelve una fila en 0 (no NULL)'
);

select results_eq(
  $$ select * from public.resumen_ventas('2187-03-01', '2187-03-31') $$,
  $$ values (100::numeric, 30::numeric, 5::numeric) $$,
  'resumen_ventas: un hasta sin hora deja afuera todo ese día (por eso la app manda el último instante)'
);

-- =====================================================================
-- Apliques
-- =====================================================================
select results_eq($$
  select * from public.top_apliques('2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999')
$$, $$ values
  ('pgTAP Mariposa', 75::numeric, 6::numeric),
  ('pgTAP Corazón',  30::numeric, 2::numeric)
$$, 'top_apliques: agrupa por aplique con el nombre de la tabla apliques, suma todos los colores y ordena por total');

select is_empty(
  $$ select * from public.top_apliques('2187-05-01T00:00:00.000', '2187-05-31T23:59:59.999999') $$,
  'top_apliques: sin ventas en el rango no devuelve filas'
);

select results_eq(
  $$ select * from public.resumen_ventas_apliques('2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999') $$,
  $$ values (105::numeric, 35::numeric, 3::numeric) $$,
  'resumen_ventas_apliques: suma total, ganancias y descuento de las ventas del rango'
);

select results_eq(
  $$ select * from public.resumen_ventas_apliques('2187-05-01T00:00:00.000', '2187-05-31T23:59:59.999999') $$,
  $$ values (0::numeric, 0::numeric, 0::numeric) $$,
  'resumen_ventas_apliques: sin ventas devuelve una fila en 0 (no NULL)'
);

-- =====================================================================
-- Renombrar no parte el historial
-- =====================================================================
update public.telas set nombre = 'pgTAP Lino renombrado' where id = pg_temp.id('lino');
update public.apliques set nombre = 'pgTAP Mariposa grande' where id = pg_temp.id('mariposa');

select results_eq($$
  select * from public.top_productos('2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999') limit 1
$$, $$ values ('pgTAP Lino renombrado', 92::numeric, 9::numeric) $$,
'top_productos: una tela renombrada conserva todo su historial con el nombre nuevo');

select results_eq($$
  select * from public.top_apliques('2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999') limit 1
$$, $$ values ('pgTAP Mariposa grande', 75::numeric, 6::numeric) $$,
'top_apliques: un aplique renombrado conserva todo su historial con el nombre nuevo');

reset role;

select * from finish();
rollback;
