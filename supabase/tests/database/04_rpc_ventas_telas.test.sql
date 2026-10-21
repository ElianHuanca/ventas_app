-- =====================================================================
-- RPC de la venta de telas
--
-- Migración 20261003000100_integridad_stock_y_ventas.sql (las usan Android
-- e iOS; el Flutter ya no):
--   * registrar_detalle_venta: upsert de líneas por (idventa, idtelas,
--     precio) sumando cantidad/total/ganancias; devuelve las filas;
--   * incrementar_venta: suma DELTAS a total/ganancias/descuento en un solo
--     UPDATE (convención incremental de actualizarVenta) y asigna fecha
--     directa (NULL = no tocarla).
-- Migración 20261020000000_idempotencia_y_venta_telas.sql (las usa el
-- Flutter; la clave p_id_operacion se prueba en 10_idempotencia.test.sql):
--   * registrar_venta_telas: en UNA transacción, la venta del día (la crea o
--     la reusa; su fecha queda la del primer registro), las líneas
--     acumuladas y a la venta el total/ganancias de esas líneas y el
--     descuento: el total de la venta es siempre la suma de sus líneas;
--   * borrar_detalle_venta: borra la línea y descuenta su total de la venta
--     en una transacción; si la línea ya no está no hace nada.
--
-- Corre como authenticated (el rol de la app). Rollback al final.
-- =====================================================================
begin;
select plan(57);

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

-- Una línea como la manda DetalleVentasDatasourceImpl (precio de compra 7)
create function pg_temp.linea(p_tela text, p_precio numeric, p_cantidad numeric)
  returns jsonb
  language sql stable
  as $$
  select jsonb_build_object(
    'idtelas',   pg_temp.id(p_tela),
    'nombre',    'pgTAP ' || p_tela,
    'precio',    p_precio,
    'cantidad',  p_cantidad,
    'total',     p_precio * p_cantidad,
    'ganancias', (p_precio - 7) * p_cantidad)
$$;

create function pg_temp.lineas_de_la_venta() returns jsonb
  language sql stable
  as $$
  select coalesce(jsonb_agg(to_jsonb(d) order by d.id), '[]')
  from public.detalle_ventas d where d.idventa = pg_temp.id('venta')
$$;

-- Llama a registrar_venta_telas como DetalleVentaFormCubit (sin clave)
create function pg_temp.vender(p_fecha text, p_descuento numeric, variadic p_lineas jsonb[])
  returns bigint
  language sql
  as $$
  select public.registrar_venta_telas(pg_temp.id('sucursal'), p_fecha, to_jsonb(p_lineas), p_descuento)
$$;

-- La venta de un día de la sucursal y la suma de sus líneas
create function pg_temp.venta_y_lineas(p_dia text) returns jsonb
  language sql stable
  as $$
  select jsonb_build_object(
    'fecha', v.fecha, 'total', v.total, 'ganancias', v.ganancias, 'descuento', v.descuento,
    'total_lineas', (select coalesce(sum(coalesce(d.total, 0)), 0) from public.detalle_ventas d where d.idventa = v.id),
    'ganancias_lineas', (select coalesce(sum(coalesce(d.ganancias, 0)), 0) from public.detalle_ventas d where d.idventa = v.id))
  from public.ventas v
  where v.idsucursales = pg_temp.id('sucursal') and left(v.fecha, 10) = p_dia
$$;

-- Todas las ventas y líneas de la sucursal del test
create function pg_temp.estado() returns jsonb
  language sql stable
  as $$
  select jsonb_build_object(
    'ventas', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]')
               from public.ventas v where v.idsucursales = pg_temp.id('sucursal')),
    'lineas', (select coalesce(jsonb_agg(to_jsonb(d) order by d.id), '[]')
               from public.detalle_ventas d join public.ventas v on v.id = d.idventa
               where v.idsucursales = pg_temp.id('sucursal')))
$$;

do $$
declare
  v_suc bigint; v_lino bigint; v_seda bigint; v_venta bigint; v_venta_11 bigint;
begin
  insert into public.sucursales (nombre) values ('pgTAP sucursal') returning id into v_suc;
  insert into public.telas (nombre, precxmen, precxcompra) values ('pgTAP lino', 10, 7) returning id into v_lino;
  insert into public.telas (nombre, precxmen, precxcompra) values ('pgTAP seda', 25, 7) returning id into v_seda;
  insert into public.ventas (fecha, idsucursales) values ('2187-03-10T09:00:00.000', v_suc)
    returning id into v_venta;
  insert into public.ventas (fecha, total, ganancias, idsucursales) values ('2187-03-11T09:00:00.000', 50, 10, v_suc)
    returning id into v_venta_11;

  insert into pg_temp._ids values
    ('sucursal', v_suc), ('lino', v_lino), ('seda', v_seda),
    ('venta', v_venta), ('venta_11', v_venta_11);
end
$$;

set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-0000000000a4", "role": "authenticated"}';

-- =====================================================================
-- registrar_detalle_venta
-- =====================================================================
select function_returns(
  'public', 'registrar_detalle_venta', array['bigint', 'jsonb'], 'setof detalle_ventas',
  'registrar_detalle_venta(bigint, jsonb) devuelve las filas de detalle_ventas'
);

select results_eq($$
  select idtelas, precio, cantidad, total, ganancias
  from public.registrar_detalle_venta(pg_temp.id('venta'), jsonb_build_array(
    pg_temp.linea('lino', 10, 2),
    pg_temp.linea('seda', 25, 1)))
  order by total
$$, $$ values
  (pg_temp.id('lino'), 10::numeric, 2::numeric, 20::numeric,  6::numeric),
  (pg_temp.id('seda'), 25::numeric, 1::numeric, 25::numeric, 18::numeric)
$$, 'inserta las líneas nuevas y las devuelve');

select results_eq($$
  select cantidad, total, ganancias
  from public.registrar_detalle_venta(pg_temp.id('venta'), jsonb_build_array(pg_temp.linea('lino', 10, 3)))
$$, $$ values (5::numeric, 50::numeric, 15::numeric) $$,
'si la línea (venta+tela+precio) ya existe suma cantidad, total y ganancias y devuelve la fila acumulada');

select results_eq($$
  select count(*) from public.detalle_ventas
  where idventa = pg_temp.id('venta') and idtelas = pg_temp.id('lino') and precio = 10
$$, array[1::bigint],
'no duplica la línea');

select lives_ok($$
  select * from public.registrar_detalle_venta(pg_temp.id('venta'), jsonb_build_array(pg_temp.linea('lino', 9, 1)))
$$, 'registra la misma tela a otro precio');

select results_eq($$
  select precio, cantidad, total, ganancias from public.detalle_ventas
  where idventa = pg_temp.id('venta') and idtelas = pg_temp.id('lino')
  order by precio
$$, $$ values (9::numeric, 1::numeric, 9::numeric, 2::numeric), (10::numeric, 5::numeric, 50::numeric, 15::numeric) $$,
'la misma tela a otro precio es otra línea');

select lives_ok($$
  select * from public.registrar_detalle_venta(pg_temp.id('venta'), jsonb_build_array(
    pg_temp.linea('seda', 25, 1),
    pg_temp.linea('seda', 25, 1)))
$$, 'registra la misma línea dos veces en un mismo envío');

select results_eq($$
  select cantidad, total, ganancias from public.detalle_ventas
  where idventa = pg_temp.id('venta') and idtelas = pg_temp.id('seda') and precio = 25
$$, $$ values (3::numeric, 75::numeric, 54::numeric) $$,
'las líneas repetidas en un envío se acumulan');

-- detalle_ventas.total/ganancias admiten NULL (filas viejas): suman desde 0
insert into public.detalle_ventas (nombre, precio, cantidad, total, ganancias, idtelas, idventa)
values ('pgTAP seda', 30, 1, null, null, pg_temp.id('seda'), pg_temp.id('venta'));

select results_eq($$
  select cantidad, total, ganancias
  from public.registrar_detalle_venta(pg_temp.id('venta'), jsonb_build_array(pg_temp.linea('seda', 30, 1)))
$$, $$ values (2::numeric, 30::numeric, 23::numeric) $$,
'una línea vieja con total/ganancias NULL acumula desde 0');

select results_eq(
  $$ select total, ganancias, descuento from public.ventas where id = pg_temp.id('venta') $$,
  $$ values (0::numeric, 0::numeric, 0::numeric) $$,
  'registrar líneas no toca los totales de la venta (eso lo hace incrementar_venta)'
);

-- Fallas: el envío entero se rechaza
insert into pg_temp._estado values ('lineas_antes', pg_temp.lineas_de_la_venta());

select throws_ok($$
  select * from public.registrar_detalle_venta(pg_temp.id('venta'), jsonb_build_array(
    pg_temp.linea('lino', 10, 1),
    pg_temp.linea('seda', 25, 0)))
$$, '23514',
'new row for relation "detalle_ventas" violates check constraint "detalle_ventas_montos_check"',
'rechaza una cantidad 0');

select throws_ok($$
  select * from public.registrar_detalle_venta(pg_temp.id('venta'), jsonb_build_array(pg_temp.linea('lino', -1, 1)))
$$, '23514',
'new row for relation "detalle_ventas" violates check constraint "detalle_ventas_montos_check"',
'rechaza un precio negativo');

select throws_ok($$
  select * from public.registrar_detalle_venta(-1, jsonb_build_array(pg_temp.linea('lino', 10, 1)))
$$, '23503', null,
'rechaza una venta que no existe');

select is(pg_temp.lineas_de_la_venta(), (select valor from pg_temp._estado where clave = 'lineas_antes'),
  'los envíos rechazados no dejaron cambios (tampoco la línea válida que venía antes)');

-- =====================================================================
-- incrementar_venta
-- =====================================================================
select function_returns(
  'public', 'incrementar_venta', array['bigint', 'numeric', 'numeric', 'numeric', 'text'], 'ventas',
  'incrementar_venta(bigint, numeric, numeric, numeric, text) devuelve la venta'
);

select results_eq($$
  select total, ganancias, descuento, fecha
  from public.incrementar_venta(pg_temp.id('venta'), 100, 30, 0, null)
$$, $$ values (100::numeric, 30::numeric, 0::numeric, '2187-03-10T09:00:00.000') $$,
'suma los deltas y devuelve la venta; p_fecha NULL no toca la fecha');

select results_eq($$
  select total, ganancias, descuento
  from public.incrementar_venta(pg_temp.id('venta'), 50, 10, 5)
$$, $$ values (150::numeric, 40::numeric, 5::numeric) $$,
'es incremental: suma al valor actual, no lo reemplaza');

select results_eq($$
  select total, ganancias, descuento
  from public.incrementar_venta(pg_temp.id('venta'), -20, -6, 0)
$$, $$ values (130::numeric, 34::numeric, 5::numeric) $$,
'acepta deltas negativos (al borrar una línea)');

select results_eq($$
  select total, ganancias, descuento
  from public.incrementar_venta(p_id => pg_temp.id('venta'), p_descuento => 2)
$$, $$ values (130::numeric, 34::numeric, 7::numeric) $$,
'los deltas que no se mandan valen 0');

select results_eq($$
  select total, ganancias, descuento, fecha
  from public.incrementar_venta(pg_temp.id('venta'), 0, 0, 0, '2187-03-10T18:30:00.000')
$$, $$ values (130::numeric, 34::numeric, 7::numeric, '2187-03-10T18:30:00.000') $$,
'la fecha se asigna directa (no es un delta)');

select results_eq(
  $$ select total, ganancias, descuento, fecha from public.ventas where id = pg_temp.id('venta') $$,
  $$ values (130::numeric, 34::numeric, 7::numeric, '2187-03-10T18:30:00.000') $$,
  'los cambios quedaron guardados en la venta'
);

select results_eq(
  $$ select total, ganancias, descuento from public.ventas where id = pg_temp.id('venta_11') $$,
  $$ values (50::numeric, 10::numeric, 0::numeric) $$,
  'no toca otras ventas'
);

select ok(
  (public.incrementar_venta(-1, 1)).id is null,
  'con una venta que no existe devuelve una fila vacía (la app la traduce a "Venta no encontrada")'
);

select throws_ok($$
  select public.incrementar_venta(pg_temp.id('venta'), 0, 0, -10)
$$, '23514',
'new row for relation "ventas" violates check constraint "ventas_descuento_no_negativo"',
'el descuento acumulado no puede quedar negativo');

select throws_ok($$
  select public.incrementar_venta(p_id => pg_temp.id('venta_11'), p_fecha => '2187-03-10T20:00:00.000')
$$, '23505',
'duplicate key value violates unique constraint "ventas_sucursal_dia_key"',
'no puede mover una venta a un día que ya tiene venta en esa sucursal');

select results_eq($$
  select total, ganancias, descuento, fecha from public.ventas
  where id in (pg_temp.id('venta'), pg_temp.id('venta_11')) order by fecha
$$, $$ values
  (130::numeric, 34::numeric, 7::numeric, '2187-03-10T18:30:00.000'),
  ( 50::numeric, 10::numeric, 0::numeric, '2187-03-11T09:00:00.000')
$$, 'las llamadas rechazadas no cambiaron nada');

-- =====================================================================
-- registrar_venta_telas
-- =====================================================================
select function_returns(
  'public', 'registrar_venta_telas', array['bigint', 'text', 'jsonb', 'numeric', 'uuid'], 'bigint',
  'registrar_venta_telas(bigint, text, jsonb, numeric, uuid) devuelve el id de la venta del día'
);

select lives_ok($$
  insert into pg_temp._ids
  select 'venta_abr', pg_temp.vender('2187-04-01T09:15:00.000', 2,
    pg_temp.linea('lino', 10, 2),
    pg_temp.linea('seda', 25, 1))
$$, 'registra una venta de telas en un día sin venta');

select is(pg_temp.venta_y_lineas('2187-04-01'),
  '{"fecha": "2187-04-01T09:15:00.000", "total": 45, "ganancias": 24, "descuento": 2, "total_lineas": 45, "ganancias_lineas": 24}'::jsonb,
  'crea la venta del día con el total y las ganancias de sus líneas y el descuento');

select results_eq($$
  select idtelas, precio, cantidad, total, ganancias from public.detalle_ventas
  where idventa = pg_temp.id('venta_abr') order by total
$$, $$ values
  (pg_temp.id('lino'), 10::numeric, 2::numeric, 20::numeric,  6::numeric),
  (pg_temp.id('seda'), 25::numeric, 1::numeric, 25::numeric, 18::numeric)
$$, 'guarda una línea por tela+precio');

-- Otro registro el mismo día (otra hora): se suma a la venta del día
select lives_ok($$
  insert into pg_temp._ids
  select 'venta_abr_tarde', pg_temp.vender('2187-04-01T17:40:00.000', 1,
    pg_temp.linea('lino', 10, 3),
    pg_temp.linea('lino', 9, 1))
$$, 'registra otra venta el mismo día');

select is(pg_temp.id('venta_abr_tarde'), pg_temp.id('venta_abr'),
  'devuelve la misma venta del día');

select is(pg_temp.venta_y_lineas('2187-04-01'),
  '{"fecha": "2187-04-01T09:15:00.000", "total": 84, "ganancias": 35, "descuento": 3, "total_lineas": 84, "ganancias_lineas": 35}'::jsonb,
  'suma total, ganancias y descuento a la venta del día y conserva la fecha del primer registro');

select results_eq($$
  select precio, cantidad, total, ganancias from public.detalle_ventas
  where idventa = pg_temp.id('venta_abr') and idtelas = pg_temp.id('lino') order by precio
$$, $$ values (9::numeric, 1::numeric, 9::numeric, 2::numeric), (10::numeric, 5::numeric, 50::numeric, 15::numeric) $$,
'la misma tela+precio acumula en su línea; otro precio es otra línea');

-- Otro dispositivo con el flujo de Android/iOS (registrar_detalle_venta +
-- incrementar_venta) vende en la misma venta: lo suyo no se pisa
select lives_ok($$
  select (select count(*) from public.registrar_detalle_venta(pg_temp.id('venta_abr'),
            jsonb_build_array(pg_temp.linea('seda', 30, 1)))),
         public.incrementar_venta(pg_temp.id('venta_abr'), 30, 23, 0, null)
$$, 'otro dispositivo suma una línea con el flujo de Android/iOS');

select lives_ok($$
  select pg_temp.vender('2187-04-01T18:00:00.000', 0,
    pg_temp.linea('seda', 25, 1),
    pg_temp.linea('seda', 25, 1))
$$, 'registra la misma línea dos veces en un envío');

select is(pg_temp.venta_y_lineas('2187-04-01'),
  '{"fecha": "2187-04-01T09:15:00.000", "total": 164, "ganancias": 94, "descuento": 3, "total_lineas": 164, "ganancias_lineas": 94}'::jsonb,
  'suma sobre lo que registró el otro dispositivo: el total sigue siendo la suma de las líneas');

select results_eq($$
  select cantidad, total, ganancias from public.detalle_ventas
  where idventa = pg_temp.id('venta_abr') and idtelas = pg_temp.id('seda') and precio = 25
$$, $$ values (3::numeric, 75::numeric, 54::numeric) $$,
'las líneas repetidas en un envío se acumulan en una');

-- Un total con más de 2 decimales: la línea lo guarda redondeado
-- (numeric(14,2)) y la venta suma ese mismo redondeo
select lives_ok($$
  select public.registrar_venta_telas(pg_temp.id('sucursal'), '2187-04-02T10:00:00.000',
    jsonb_build_array(jsonb_build_object('idtelas', pg_temp.id('lino'), 'nombre', 'pgTAP lino',
      'precio', 0.05, 'cantidad', 2.5, 'total', 0.125, 'ganancias', 0.005)), 0)
$$, 'registra una línea con total y ganancias de 3 decimales');

select is(pg_temp.venta_y_lineas('2187-04-02'),
  '{"fecha": "2187-04-02T10:00:00.000", "total": 0.13, "ganancias": 0.01, "descuento": 0, "total_lineas": 0.13, "ganancias_lineas": 0.01}'::jsonb,
  'la venta suma el total de la línea tal como quedó guardado (redondeado a centavos)');

-- Fallas: el envío entero se rechaza y no deja nada (ni la venta del día)
insert into pg_temp._estado values ('telas_antes', pg_temp.estado());

select throws_ok($$
  select pg_temp.vender('2187-04-03T10:00:00.000', 0,
    pg_temp.linea('lino', 10, 1),
    pg_temp.linea('seda', 25, 0))
$$, '23514',
'new row for relation "detalle_ventas" violates check constraint "detalle_ventas_montos_check"',
'rechaza una cantidad 0');

select throws_ok($$
  select pg_temp.vender('2187-04-01T19:00:00.000', 0, pg_temp.linea('lino', -1, 1))
$$, '23514',
'new row for relation "detalle_ventas" violates check constraint "detalle_ventas_montos_check"',
'rechaza un precio negativo en un día que ya tiene venta');

select throws_ok($$
  select public.registrar_venta_telas(pg_temp.id('sucursal'), '2187-04-03T10:00:00.000',
    jsonb_build_array(jsonb_build_object('idtelas', -1, 'nombre', 'x', 'precio', 1, 'cantidad', 1, 'total', 1, 'ganancias', 0)), 0)
$$, '23503', null,
'rechaza una tela que no existe');

select throws_ok($$
  select pg_temp.vender('2187-04-03T10:00:00.000', -1, pg_temp.linea('lino', 10, 1))
$$, 'P0001', 'El descuento no puede ser negativo',
'rechaza un descuento negativo');

select throws_ok($$
  select public.registrar_venta_telas(pg_temp.id('sucursal'), '2187-04-03T10:00:00.000',
    jsonb_build_array(pg_temp.linea('lino', 10, 1) - 'total'), 0)
$$, 'P0001', 'Línea sin total o ganancias: pgTAP lino',
'rechaza una línea sin total (la venta no podría sumar lo mismo que sus líneas)');

select throws_ok($$
  select public.registrar_venta_telas(pg_temp.id('sucursal'), '2187-04-03T10:00:00.000', '[]'::jsonb, 0)
$$, 'P0001', 'La venta no tiene líneas',
'rechaza una venta sin líneas');

select throws_ok($$
  select public.registrar_venta_telas(pg_temp.id('sucursal'), '2187-04-03T10:00:00.000', null, 0)
$$, 'P0001', 'La venta no tiene líneas',
'rechaza p_detalles NULL');

select throws_ok($$
  select public.registrar_venta_telas(pg_temp.id('sucursal'), '2187-04-03T10:00:00.000', '{}'::jsonb, 0)
$$, 'P0001', 'La venta no tiene líneas',
'rechaza p_detalles que no es un arreglo');

select is(pg_temp.estado(), (select valor from pg_temp._estado where clave = 'telas_antes'),
  'los envíos rechazados no dejaron venta del día, líneas ni totales (tampoco la línea válida que venía antes)');

-- =====================================================================
-- borrar_detalle_venta
-- =====================================================================
select function_returns(
  'public', 'borrar_detalle_venta', array['bigint'], 'ventas',
  'borrar_detalle_venta(bigint) devuelve la venta'
);

insert into pg_temp._ids
select 'linea_lino_9', id from public.detalle_ventas
where idventa = pg_temp.id('venta_abr') and idtelas = pg_temp.id('lino') and precio = 9;

select results_eq($$
  select id, total, ganancias, descuento from public.borrar_detalle_venta(pg_temp.id('linea_lino_9'))
$$, $$ values (pg_temp.id('venta_abr'), 155::numeric, 92::numeric, 3::numeric) $$,
'borra la línea y devuelve la venta con su total y sus ganancias descontados');

select is_empty(
  $$ select 1 from public.detalle_ventas where id = pg_temp.id('linea_lino_9') $$,
  'la línea quedó borrada');

select is(pg_temp.venta_y_lineas('2187-04-01'),
  '{"fecha": "2187-04-01T09:15:00.000", "total": 155, "ganancias": 92, "descuento": 3, "total_lineas": 155, "ganancias_lineas": 92}'::jsonb,
  'la venta queda con la suma de las líneas que siguen');

select ok(
  (public.borrar_detalle_venta(pg_temp.id('linea_lino_9'))).id is null,
  'borrar una línea que ya no existe (reintento, u otro dispositivo) no hace nada y devuelve NULL');

select is(pg_temp.venta_y_lineas('2187-04-01'),
  '{"fecha": "2187-04-01T09:15:00.000", "total": 155, "ganancias": 92, "descuento": 3, "total_lineas": 155, "ganancias_lineas": 92}'::jsonb,
  'el segundo borrado no vuelve a descontar el total');

-- Una línea vieja sin total ni ganancias: se borra y no descuenta nada
insert into public.detalle_ventas (nombre, precio, cantidad, total, ganancias, idtelas, idventa)
values ('pgTAP lino', 11, 1, null, null, pg_temp.id('lino'), pg_temp.id('venta_11'));

select results_eq($$
  select total, ganancias from public.borrar_detalle_venta(
    (select id from public.detalle_ventas where idventa = pg_temp.id('venta_11') and precio = 11))
$$, $$ values (50::numeric, 10::numeric) $$,
'una línea con total/ganancias NULL se borra sin descontar nada de la venta');

select results_eq(
  $$ select total, ganancias from public.ventas where id = pg_temp.id('venta_abr') $$,
  $$ values (155::numeric, 92::numeric) $$,
  'borrar una línea de otra venta no toca esta'
);

reset role;

select * from finish();
rollback;
