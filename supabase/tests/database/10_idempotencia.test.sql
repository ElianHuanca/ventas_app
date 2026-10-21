-- =====================================================================
-- Idempotencia de las RPC de escritura (p_id_operacion)
--
-- Migración 20261020000000_idempotencia_y_venta_telas.sql: la app manda
-- una clave (uuid) por envío y la reusa si reintenta (respuesta perdida
-- después del commit). crear_venta_apliques, registrar_produccion y
-- registrar_venta_telas:
--   * con una clave nueva aplican y la guardan en operaciones_aplicadas (rpc
--     + resultado) en la misma transacción;
--   * con una clave ya aplicada devuelven el resultado de entonces SIN
--     aplicar nada (aunque el contenido sea otro: es la app la que renueva
--     la clave cuando cambia el envío);
--   * si fallan, la clave se revierte con todo lo demás: el reintento aplica;
--   * una clave de otra RPC es un error (HINT operacion_de_otra_rpc);
--   * sin clave hacen lo mismo que antes (apps viejas, Android, iOS).
-- borrar_detalle_venta es idempotente sin clave (04).
--
-- Corre como authenticated (el rol de la app). Rollback al final.
-- =====================================================================
begin;
select plan(33);

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

-- Las claves del test (uuid fijos: los mensajes de error las nombran)
create function pg_temp.clave(p_letra text) returns uuid
  language sql immutable
  as $$ select ('00000000-0000-4000-8000-0000000000' || lpad(p_letra, 2, '0'))::uuid $$;

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

-- Venta de apliques de [p_cantidad] mariposas rojas a 10 (costo 6), como
-- VentaApliquesFormCubit, con la clave [p_clave] (NULL = sin clave)
create function pg_temp.vender_apliques(p_clave uuid, p_cantidad numeric) returns bigint
  language sql
  as $$
  select public.crear_venta_apliques(
    p_idsucursales => pg_temp.id('sucursal'),
    p_fecha        => '2187-05-10T10:00:00.000',
    p_total        => 10 * p_cantidad,
    p_ganancias    => 4 * p_cantidad,
    p_descuento    => 0,
    p_detalles     => jsonb_build_array(jsonb_build_object(
      'idapliques', pg_temp.id('mariposa'), 'idcolor', pg_temp.id('rojo'),
      'nombre', 'pgTAP mariposa (rojo)', 'precio', 10, 'cantidad', p_cantidad,
      'total', 10 * p_cantidad, 'ganancias', 4 * p_cantidad)),
    p_id_operacion => p_clave)
$$;

-- Fabricación de [p_cantidad] mariposas rojas, como ProduccionFormCubit
create function pg_temp.fabricar(p_clave uuid, p_cantidad numeric) returns bigint
  language sql
  as $$
  select public.registrar_produccion(
    p_sucursal_id  => pg_temp.id('sucursal'),
    p_fecha        => '2187-05-10',
    p_lineas       => jsonb_build_array(jsonb_build_object(
      'idaplique', pg_temp.id('mariposa'), 'idcolor', pg_temp.id('rojo'), 'cantidad', p_cantidad)),
    p_id_operacion => p_clave)
$$;

-- Venta de [p_cantidad] m de lino a 10 (compra 7), como DetalleVentaFormCubit
create function pg_temp.vender_telas(p_clave uuid, p_cantidad numeric) returns bigint
  language sql
  as $$
  select public.registrar_venta_telas(
    p_idsucursales => pg_temp.id('sucursal'),
    p_fecha        => '2187-05-10T10:00:00.000',
    p_detalles     => jsonb_build_array(jsonb_build_object(
      'idtelas', pg_temp.id('lino'), 'nombre', 'pgTAP lino', 'precio', 10,
      'cantidad', p_cantidad, 'total', 10 * p_cantidad, 'ganancias', 3 * p_cantidad)),
    p_descuento    => 1,
    p_id_operacion => p_clave)
$$;

create function pg_temp.stock() returns numeric
  language sql stable
  as $$
  select stock from public.inventario
  where sucursal_id = pg_temp.id('sucursal') and aplique_id = pg_temp.id('mariposa')
    and color_id = pg_temp.id('rojo')
$$;

-- Todo lo que pueden tocar las tres RPC en la sucursal del test
create function pg_temp.estado() returns jsonb
  language sql stable
  as $$
  select jsonb_build_object(
    'ventas_apliques', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]')
      from public.ventas_apliques v where v.idsucursales = pg_temp.id('sucursal')),
    'lineas_apliques', (select coalesce(jsonb_agg(to_jsonb(d) order by d.id), '[]')
      from public.detalle_ventas_apliques d join public.ventas_apliques v on v.id = d.idventa
      where v.idsucursales = pg_temp.id('sucursal')),
    'producciones', (select coalesce(jsonb_agg(to_jsonb(p) order by p.id), '[]')
      from public.producciones p where p.sucursal_id = pg_temp.id('sucursal')),
    'lineas_produccion', (select coalesce(jsonb_agg(to_jsonb(d) order by d.id), '[]')
      from public.detalle_produccion d join public.producciones p on p.id = d.idproduccion
      where p.sucursal_id = pg_temp.id('sucursal')),
    'inventario', (select coalesce(jsonb_agg(to_jsonb(i) order by i.aplique_id, i.color_id), '[]')
      from public.inventario i where i.sucursal_id = pg_temp.id('sucursal')),
    'ventas', (select coalesce(jsonb_agg(to_jsonb(v) order by v.id), '[]')
      from public.ventas v where v.idsucursales = pg_temp.id('sucursal')),
    'lineas_telas', (select coalesce(jsonb_agg(to_jsonb(d) order by d.id), '[]')
      from public.detalle_ventas d join public.ventas v on v.id = d.idventa
      where v.idsucursales = pg_temp.id('sucursal')),
    'operaciones', (select coalesce(jsonb_agg(jsonb_build_object('id', o.id, 'rpc', o.rpc, 'resultado', o.resultado) order by o.id), '[]')
      from public.operaciones_aplicadas o where o.id::text like '00000000-0000-4000-8000-%'))
$$;

do $$
declare
  v_suc bigint; v_rojo bigint; v_mariposa bigint; v_lino bigint;
begin
  insert into public.sucursales (nombre) values ('pgTAP sucursal') returning id into v_suc;
  insert into public.colores (nombre) values ('pgTAP rojo') returning id into v_rojo;
  insert into public.apliques (nombre, costo_fabricacion) values ('pgTAP Mariposa', 6) returning id into v_mariposa;
  insert into public.aplique_colores (idaplique, idcolor) values (v_mariposa, v_rojo);
  insert into public.inventario (sucursal_id, aplique_id, color_id, stock) values (v_suc, v_mariposa, v_rojo, 10);
  insert into public.telas (nombre, precxmen, precxcompra) values ('pgTAP lino', 10, 7) returning id into v_lino;

  insert into pg_temp._ids values
    ('sucursal', v_suc), ('rojo', v_rojo), ('mariposa', v_mariposa), ('lino', v_lino);
end
$$;

set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-0000000000b0", "role": "authenticated"}';

-- =====================================================================
-- crear_venta_apliques
-- =====================================================================
select lives_ok($$
  insert into pg_temp._ids select 'va_1', pg_temp.vender_apliques(pg_temp.clave('1'), 2)
$$, 'crear_venta_apliques con una clave nueva vende');

insert into pg_temp._estado values ('va_1', pg_temp.estado());

select is(pg_temp.stock(), 8::numeric, 'descuenta el stock');

select results_eq(
  $$ select rpc, resultado from public.operaciones_aplicadas where id = pg_temp.clave('1') $$,
  $$ values ('crear_venta_apliques', pg_temp.id('va_1')) $$,
  'guarda la clave con la RPC y el id de la venta'
);

select is(pg_temp.vender_apliques(pg_temp.clave('1'), 2), pg_temp.id('va_1'),
  'la misma clave otra vez (reintento) devuelve la misma venta');

select is(pg_temp.estado(), (select valor from pg_temp._estado where clave = 'va_1'),
  'y no vuelve a aplicar nada: stock, venta del día, líneas y claves iguales');

select is(pg_temp.vender_apliques(pg_temp.clave('1'), 5), pg_temp.id('va_1'),
  'con la misma clave y otro contenido también devuelve lo de la primera vez');

select is(pg_temp.estado(), (select valor from pg_temp._estado where clave = 'va_1'),
  'sin aplicar el contenido nuevo (la app renueva la clave cuando cambia el envío)');

select is(pg_temp.vender_apliques(pg_temp.clave('2'), 1), pg_temp.id('va_1'),
  'otra clave es otro envío: se suma a la venta del día');

select is(pg_temp.stock(), 7::numeric, 'y descuenta su stock');

select lives_ok($$
  select pg_temp.vender_apliques(null, 1), pg_temp.vender_apliques(null, 1)
$$, 'sin clave (apps viejas, Android, iOS) vende como antes');

select results_eq($$
  select pg_temp.stock(), v.total, (select sum(cantidad) from public.detalle_ventas_apliques where idventa = v.id)
  from public.ventas_apliques v where v.id = pg_temp.id('va_1')
$$, $$ values (5::numeric, 50::numeric, 5::numeric) $$,
'sin clave cada llamada se aplica (dos llamadas = dos ventas sumadas)');

-- Una venta rechazada no gasta la clave: el reintento (con stock) vende
select throws_ok($$
  select pg_temp.vender_apliques(pg_temp.clave('3'), 6)
$$, 'P0001', 'Stock insuficiente: pgTAP mariposa (rojo)',
'con una clave nueva y sin stock la venta se rechaza');

select is_empty(
  $$ select 1 from public.operaciones_aplicadas where id = pg_temp.clave('3') $$,
  'la venta rechazada no deja su clave guardada');

select lives_ok($$
  select pg_temp.fabricar(null, 1), pg_temp.vender_apliques(pg_temp.clave('3'), 6)
$$, 'con stock, el reintento con la misma clave vende');

select is(pg_temp.stock(), 0::numeric, 'y descuenta el stock una vez');

-- =====================================================================
-- registrar_produccion
-- =====================================================================
select lives_ok($$
  insert into pg_temp._ids select 'p_1', pg_temp.fabricar(pg_temp.clave('4'), 5)
$$, 'registrar_produccion con una clave nueva fabrica');

insert into pg_temp._estado values ('p_1', pg_temp.estado());

select results_eq(
  $$ select rpc, resultado from public.operaciones_aplicadas where id = pg_temp.clave('4') $$,
  $$ values ('registrar_produccion', pg_temp.id('p_1')) $$,
  'guarda la clave con la RPC y el id de la producción'
);

select is(pg_temp.fabricar(pg_temp.clave('4'), 5), pg_temp.id('p_1'),
  'la misma clave otra vez devuelve la misma producción');

select is(pg_temp.estado(), (select valor from pg_temp._estado where clave = 'p_1'),
  'y no vuelve a sumar la línea ni el stock');

select is(pg_temp.fabricar(pg_temp.clave('5'), 5), pg_temp.id('p_1'),
  'otra clave es otro envío: misma producción del día');

select lives_ok($$ select pg_temp.fabricar(null, 2), pg_temp.fabricar(null, 2) $$,
  'sin clave fabrica como antes');

select results_eq($$
  select pg_temp.stock(), (select cantidad from public.detalle_produccion
                            where idproduccion = pg_temp.id('p_1') and idaplique = pg_temp.id('mariposa'))
$$, $$ values (14::numeric, 15::numeric) $$,
'otra clave y cada llamada sin clave suman a la línea y al stock (la del 1 de antes también)');

-- =====================================================================
-- registrar_venta_telas
-- =====================================================================
select lives_ok($$
  insert into pg_temp._ids select 'vt_1', pg_temp.vender_telas(pg_temp.clave('6'), 2)
$$, 'registrar_venta_telas con una clave nueva vende');

insert into pg_temp._estado values ('vt_1', pg_temp.estado());

select results_eq(
  $$ select rpc, resultado from public.operaciones_aplicadas where id = pg_temp.clave('6') $$,
  $$ values ('registrar_venta_telas', pg_temp.id('vt_1')) $$,
  'guarda la clave con la RPC y el id de la venta'
);

select is(pg_temp.vender_telas(pg_temp.clave('6'), 2), pg_temp.id('vt_1'),
  'la misma clave otra vez devuelve la misma venta');

select is(pg_temp.estado(), (select valor from pg_temp._estado where clave = 'vt_1'),
  'y no vuelve a sumar las líneas, el total ni el descuento');

select is(pg_temp.vender_telas(pg_temp.clave('7'), 1), pg_temp.id('vt_1'),
  'otra clave es otro envío: se suma a la venta del día');

select lives_ok($$ select pg_temp.vender_telas(null, 1) $$, 'sin clave vende como antes');

select results_eq($$
  select v.total, v.ganancias, v.descuento, d.cantidad, d.total
  from public.ventas v join public.detalle_ventas d on d.idventa = v.id
  where v.id = pg_temp.id('vt_1')
$$, $$ values (40::numeric, 12::numeric, 3::numeric, 4::numeric, 40::numeric) $$,
'tres envíos aplicados (2 + 1 + 1 m): el total sigue siendo la suma de la línea');

-- =====================================================================
-- Una clave es de una sola RPC
-- =====================================================================
insert into pg_temp._estado values ('final', pg_temp.estado());

select throws_ok($$
  select pg_temp.fabricar(pg_temp.clave('1'), 1)
$$, 'P0001', 'La clave de operación 00000000-0000-4000-8000-000000000001 ya se usó en crear_venta_apliques',
'registrar_produccion rechaza una clave que ya usó crear_venta_apliques');

select is(
  pg_temp.error_de($$ select pg_temp.vender_apliques(pg_temp.clave('6'), 1) $$)->>'hint',
  'operacion_de_otra_rpc',
  'crear_venta_apliques rechaza una clave de registrar_venta_telas (HINT operacion_de_otra_rpc)');

select is(
  pg_temp.error_de($$ select pg_temp.vender_telas(pg_temp.clave('4'), 1) $$)->>'hint',
  'operacion_de_otra_rpc',
  'registrar_venta_telas rechaza una clave de registrar_produccion (HINT operacion_de_otra_rpc)');

select is(pg_temp.estado(), (select valor from pg_temp._estado where clave = 'final'),
  'las llamadas con una clave de otra RPC no aplicaron nada');

reset role;

select * from finish();
rollback;
