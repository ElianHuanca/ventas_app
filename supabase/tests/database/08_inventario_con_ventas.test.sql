-- =====================================================================
-- RPC inventario_con_ventas (pantalla Inventario: faltantes de apliques)
--
-- Migración 20261015000000_inventario_con_ventas.sql.
--   * devuelve el inventario ACTIVO de la sucursal cuyo aplique, color y
--     vínculo aplique_colores siguen activos (lo mismo que ofrece la venta);
--   * vendidas: unidades vendidas en ESA sucursal con ventas_apliques.fecha
--     entre desde y hasta inclusive, comparando como TEXTO ISO8601 (por eso
--     la app manda hasta = '…T23:59:59.999999');
--   * vendidas_otras: lo vendido en las otras sucursales dividido por
--     cuántas de ellas vendieron apliques en el rango (una sin ventas no baja
--     el promedio); 0 si ninguna vendió.
--
-- Los datos van en 2187 para no mezclarse con ventas reales (el promedio
-- cuenta TODAS las sucursales que vendieron en el rango). Corre como
-- authenticated. Rollback al final.
-- =====================================================================
begin;
select plan(19);

-- ---------------------------------------------------------------------
-- Datos de apoyo (solo viven en esta transacción)
-- ---------------------------------------------------------------------
create temp table _ids (clave text primary key, id bigint not null) on commit drop;
grant all on _ids to public;
create function pg_temp.id(p_clave text) returns bigint
  language sql stable
  as $$ select id from pg_temp._ids where clave = p_clave $$;

-- La fila de un aplique+color en el inventario de una sucursal (o nada)
create function pg_temp.fila(p_sucursal text, p_aplique text, p_color text,
                             p_desde text, p_hasta text)
  returns table(stock numeric, vendidas numeric, vendidas_otras numeric)
  language sql stable
  as $$
  select r.stock, r.vendidas, r.vendidas_otras
  from public.inventario_con_ventas(pg_temp.id(p_sucursal), p_desde, p_hasta) r
  where r.aplique_id = pg_temp.id(p_aplique) and r.color_id = pg_temp.id(p_color)
$$;

-- Una venta de apliques (cabecera del día) con sus líneas: (aplique, color,
-- precio, cantidad). Los totales de la cabecera no importan acá.
create function pg_temp.venta(p_sucursal text, p_fecha text, variadic p_lineas text[])
  returns void
  language plpgsql
  as $$
declare
  v_venta bigint;
  v_linea text;
  v_partes text[];
begin
  insert into public.ventas_apliques (fecha, idsucursales)
    values (p_fecha, pg_temp.id(p_sucursal)) returning id into v_venta;
  foreach v_linea in array p_lineas loop
    v_partes := string_to_array(v_linea, ' ');
    insert into public.detalle_ventas_apliques
      (idventa, idapliques, idcolor, nombre, precio, cantidad, total, ganancias)
    values (v_venta, pg_temp.id(v_partes[1]), pg_temp.id(v_partes[2]), 'x',
            v_partes[3]::numeric, v_partes[4]::numeric,
            v_partes[3]::numeric * v_partes[4]::numeric, 0);
  end loop;
end
$$;

--   sucursal (la que se consulta), inventario:
--     mariposa rojo     stock 4  → aparece (vende)
--     mariposa azul     stock 0  → aparece (solo venden las otras)
--     corazon verde     stock 7  → aparece (nadie lo vende; color sin hex)
--     mariposa blanco   stock 3  → afuera: vínculo aplique_colores inactivo
--     mariposa negro    stock 2  → afuera: color inactivo
--     corazon rojo      stock 5  → afuera: fila de inventario inactiva
--     corazon azul      stock 1  → afuera: color nunca vinculado al aplique
--     estrella rojo     stock 1  → afuera: aplique inactivo
--   otra_1: mariposa rojo stock 9. otra_2: sin inventario.
do $$
declare
  v_suc bigint; v_o1 bigint; v_o2 bigint;
  v_rojo bigint; v_azul bigint; v_verde bigint; v_blanco bigint; v_negro bigint;
  v_mariposa bigint; v_corazon bigint; v_estrella bigint;
begin
  insert into public.sucursales (nombre) values ('pgTAP sucursal') returning id into v_suc;
  insert into public.sucursales (nombre) values ('pgTAP otra 1') returning id into v_o1;
  insert into public.sucursales (nombre) values ('pgTAP otra 2') returning id into v_o2;
  insert into public.colores (nombre, hex) values ('pgTAP rojo', '#FF0000') returning id into v_rojo;
  insert into public.colores (nombre, hex) values ('pgTAP azul', '#0000FF') returning id into v_azul;
  insert into public.colores (nombre) values ('pgTAP verde') returning id into v_verde;
  insert into public.colores (nombre, hex) values ('pgTAP blanco', '#FFFFFF') returning id into v_blanco;
  insert into public.colores (nombre, hex, activo) values ('pgTAP negro', '#000000', false) returning id into v_negro;
  insert into public.apliques (nombre) values ('pgTAP Mariposa') returning id into v_mariposa;
  insert into public.apliques (nombre) values ('pgTAP Corazón') returning id into v_corazon;
  insert into public.apliques (nombre, activo) values ('pgTAP Estrella', false) returning id into v_estrella;

  insert into public.aplique_colores (idaplique, idcolor, activo) values
    (v_mariposa, v_rojo, true), (v_mariposa, v_azul, true),
    (v_mariposa, v_blanco, false), (v_mariposa, v_negro, true),
    (v_corazon, v_rojo, true), (v_corazon, v_verde, true),
    (v_estrella, v_rojo, true);

  insert into public.inventario (sucursal_id, aplique_id, color_id, stock, activo) values
    (v_suc, v_mariposa, v_rojo, 4, true),
    (v_suc, v_mariposa, v_azul, 0, true),
    (v_suc, v_corazon, v_verde, 7, true),
    (v_suc, v_mariposa, v_blanco, 3, true),
    (v_suc, v_mariposa, v_negro, 2, true),
    (v_suc, v_corazon, v_rojo, 5, false),
    (v_suc, v_corazon, v_azul, 1, true),
    (v_suc, v_estrella, v_rojo, 1, true),
    (v_o1, v_mariposa, v_rojo, 9, true);

  insert into pg_temp._ids values
    ('sucursal', v_suc), ('otra_1', v_o1), ('otra_2', v_o2),
    ('rojo', v_rojo), ('azul', v_azul), ('verde', v_verde),
    ('blanco', v_blanco), ('negro', v_negro),
    ('mariposa', v_mariposa), ('corazon', v_corazon), ('estrella', v_estrella);
end
$$;

-- Ventas. En marzo: sucursal vende 6 mariposa rojo (en los dos bordes del
-- mes), otra_1 vende 5 rojo + 4 azul y otra_2 vende 3 rojo. Afuera de marzo
-- hay ventas grandes (100) que no tienen que contar.
do $$
begin
  perform pg_temp.venta('sucursal', '2187-02-28T23:59:59.999', 'mariposa rojo 10 100');
  perform pg_temp.venta('sucursal', '2187-03-01T00:00:00.000', 'mariposa rojo 10 2', 'mariposa rojo 12 1');
  perform pg_temp.venta('sucursal', '2187-03-31T23:59:59.500', 'mariposa rojo 10 3');
  perform pg_temp.venta('sucursal', '2187-04-01T00:00:00.000', 'mariposa rojo 10 100');
  perform pg_temp.venta('otra_1',   '2187-03-10T10:00:00.000', 'mariposa rojo 10 5', 'mariposa azul 10 4');
  perform pg_temp.venta('otra_1',   '2187-04-02T10:00:00.000', 'mariposa rojo 10 100');
  perform pg_temp.venta('otra_2',   '2187-02-20T10:00:00.000', 'mariposa rojo 10 100');
  perform pg_temp.venta('otra_2',   '2187-03-15T10:00:00.000', 'mariposa rojo 10 3');
  -- En mayo: sucursal vende 10 y otra_1 6; otra_2 no vende nada
  perform pg_temp.venta('sucursal', '2187-05-10T10:00:00.000', 'mariposa rojo 10 10');
  perform pg_temp.venta('otra_1',   '2187-05-12T10:00:00.000', 'mariposa rojo 10 6');
end
$$;

set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-0000000000a8", "role": "authenticated"}';

-- =====================================================================
-- Firma (la app mapea estas columnas: no pueden cambiar)
-- =====================================================================
select is(
  pg_get_function_result('public.inventario_con_ventas(bigint,text,text)'::regprocedure),
  'TABLE(aplique_id bigint, aplique text, color_id bigint, color text, hex text, stock numeric, vendidas numeric, vendidas_otras numeric)',
  'inventario_con_ventas(p_sucursal_id bigint, desde text, hasta text) devuelve aplique, color, hex, stock, vendidas y vendidas_otras'
);
select is(
  (select provolatile from pg_proc where oid = 'public.inventario_con_ventas(bigint,text,text)'::regprocedure),
  's'::"char",
  'inventario_con_ventas es STABLE (solo lee)'
);

-- =====================================================================
-- Filtros: lo mismo que ofrece la venta
-- =====================================================================
select results_eq($$
  select aplique_id, color_id
  from public.inventario_con_ventas(pg_temp.id('sucursal'), '2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999')
$$, $$ values
  (pg_temp.id('corazon'),  pg_temp.id('verde')),
  (pg_temp.id('mariposa'), pg_temp.id('azul')),
  (pg_temp.id('mariposa'), pg_temp.id('rojo'))
$$, 'devuelve solo el inventario activo con aplique, color y vínculo activos, ordenado por aplique y color');

select is_empty(
  $$ select * from pg_temp.fila('sucursal', 'corazon', 'rojo', '2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999') $$,
  'deja afuera una fila de inventario inactiva (aunque tenga stock)'
);
select is_empty(
  $$ select * from pg_temp.fila('sucursal', 'estrella', 'rojo', '2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999') $$,
  'deja afuera un aplique inactivo'
);
select is_empty(
  $$ select * from pg_temp.fila('sucursal', 'mariposa', 'negro', '2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999') $$,
  'deja afuera un color inactivo'
);
select is_empty(
  $$ select * from pg_temp.fila('sucursal', 'mariposa', 'blanco', '2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999') $$,
  'deja afuera un color con el vínculo aplique_colores inactivo'
);
select is_empty(
  $$ select * from pg_temp.fila('sucursal', 'corazon', 'azul', '2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999') $$,
  'deja afuera un color que nunca se vinculó al aplique'
);

select is_empty(
  $$ select * from public.inventario_con_ventas(pg_temp.id('otra_2'), '2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999') $$,
  'una sucursal sin inventario no devuelve filas (aunque haya vendido)'
);

-- =====================================================================
-- Filas completas
-- =====================================================================
select results_eq($$
  select aplique, color, hex, stock, vendidas, vendidas_otras
  from public.inventario_con_ventas(pg_temp.id('sucursal'), '2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999')
$$, $$ values
  ('pgTAP Corazón',  'pgTAP verde', '',        7::numeric, 0::numeric, 0::numeric),
  ('pgTAP Mariposa', 'pgTAP azul',  '#0000FF', 0::numeric, 0::numeric, 2::numeric),
  ('pgTAP Mariposa', 'pgTAP rojo',  '#FF0000', 4::numeric, 6::numeric, 4::numeric)
$$, 'devuelve nombres, hex ('''' si el color no tiene), stock y lo vendido de cada aplique+color');

-- =====================================================================
-- vendidas: solo esa sucursal y solo el rango
-- =====================================================================
select is(
  (select vendidas from pg_temp.fila('sucursal', 'mariposa', 'rojo', '2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999')),
  6::numeric,
  'vendidas suma todas las líneas del aplique+color en el rango, con los bordes (…T00:00:00.000 y …T23:59:59.500 con hasta …T23:59:59.999999) y sin las de antes ni después'
);

select is(
  (select vendidas from pg_temp.fila('sucursal', 'mariposa', 'rojo', '2187-03-01T00:00:00.000', '2187-03-31T23:59:59')),
  3::numeric,
  'compara fecha como texto: hasta "…T23:59:59" deja afuera "…T23:59:59.500"'
);

select is(
  (select vendidas from pg_temp.fila('sucursal', 'mariposa', 'azul', '2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999')),
  0::numeric,
  'vendidas no cuenta lo que vendieron las otras sucursales'
);

select results_eq(
  $$ select vendidas, vendidas_otras from pg_temp.fila('otra_1', 'mariposa', 'rojo', '2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999') $$,
  $$ values (5::numeric, 4.5::numeric) $$,
  'desde otra sucursal: vendidas es la suya y vendidas_otras el promedio de las demás ((6 + 3) / 2)'
);

-- =====================================================================
-- vendidas_otras: promedio de las otras que vendieron
-- =====================================================================
select is(
  (select vendidas_otras from pg_temp.fila('sucursal', 'mariposa', 'rojo', '2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999')),
  4::numeric,
  'vendidas_otras es el promedio de las otras sucursales en el rango ((5 + 3) / 2), sin la propia ni las ventas fuera del rango'
);

select is(
  (select vendidas_otras from pg_temp.fila('sucursal', 'mariposa', 'azul', '2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999')),
  2::numeric,
  'divide por las otras sucursales que vendieron apliques en el rango aunque no ese color (4 / 2)'
);

select results_eq(
  $$ select vendidas, vendidas_otras from pg_temp.fila('sucursal', 'mariposa', 'rojo', '2187-05-01T00:00:00.000', '2187-05-31T23:59:59.999999') $$,
  $$ values (10::numeric, 6::numeric) $$,
  'con 2 otras sucursales, la que no vendió en el rango no baja el promedio (6 / 1, no 6 / 2)'
);

-- =====================================================================
-- Sin ventas: 0, no NULL
-- =====================================================================
select results_eq(
  $$ select vendidas, vendidas_otras from pg_temp.fila('sucursal', 'corazon', 'verde', '2187-03-01T00:00:00.000', '2187-03-31T23:59:59.999999') $$,
  $$ values (0::numeric, 0::numeric) $$,
  'un aplique+color que nadie vendió en el rango da vendidas y vendidas_otras 0'
);

select results_eq($$
  select stock, vendidas, vendidas_otras
  from public.inventario_con_ventas(pg_temp.id('sucursal'), '2187-06-01T00:00:00.000', '2187-06-30T23:59:59.999999')
$$, $$ values
  (7::numeric, 0::numeric, 0::numeric),
  (0::numeric, 0::numeric, 0::numeric),
  (4::numeric, 0::numeric, 0::numeric)
$$, 'sin ventas de nadie en el rango devuelve el inventario con vendidas y vendidas_otras en 0 (no NULL)');

reset role;

select * from finish();
rollback;
