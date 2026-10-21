-- =====================================================================
-- Contrato del esquema compartido
--
-- Lo que las apps que comparten esta base leen y escriben, relevado de su
-- código (2026-10-20). Si una migración renombra, borra o cambia el tipo de
-- algo de esta lista, este test falla antes de que se rompa una app en
-- producción: reemplaza el "revisar a mano si sitio, Android o iOS usan la
-- columna" del runbook de cambios de esquema.
--
-- Consumidores:
--   Flutter = este repo: lib/features/*/infrastructure/ (datasources y mappers)
--   Android = ventas_app_android, rama master: *DatasourceImpl.kt y dto/*Row.kt
--   iOS     = ventas_app_ios: VentasApp/Features/*/Infrastructure/*Supabase.swift
--   web     = sitio: lib/data.ts (solo las vistas *_web)
--
-- Qué fija:
--   1. tablas y vistas; por columna usada, que exista, su tipo base y NOT NULL
--      donde una app la decodifica como no nula. Android es el estricto: un
--      tipo Kotlin no nulo (aunque tenga default) con un null en el JSON
--      rompe el decode, porque supabase-kt no usa coerceInputValues. Flutter
--      falla con `as int`. iOS y la web toleran null en todo;
--   2. lo que PostgREST necesita para los embeds y upserts de las apps: la FK
--      de cada embed (y que sea la única entre esas dos tablas) y las PK por
--      las que resuelve el upsert;
--   3. que las apps puedan seguir insertando: ninguna columna NOT NULL sin
--      default fuera de las que mandan;
--   4. las RPC: tipos y NOMBRES de los parámetros (PostgREST llama por
--      nombre: renombrar p_fecha rompe a todas aunque el tipo no cambie), el
--      resultado (con las columnas de RETURNS TABLE, que function_returns no
--      ve) y las claves del JSON de p_detalles / p_lineas.
--
-- El tipo se compara sin precisión: numeric(12,2) → numeric(14,2) no rompe a
-- nadie (llega como número JSON); numeric → text sí (llega como string).
-- No repite lo de otros archivos: permisos de anon/authenticated y DELETE
-- (01), UNIQUE por sucursal+día que da el 23505 que atrapan las tres apps
-- (05), columnas exactas de las vistas web (07).
--
-- Al cambiar lo que usa una app: actualizar estas listas (y el plan).
-- Corre en una transacción con rollback: no deja datos.
-- =====================================================================
begin;
select plan(279);

create temp table _ids (clave text primary key, id bigint not null) on commit drop;
create function pg_temp.id(p_clave text) returns bigint
  language sql stable
  as $$ select id from pg_temp._ids where clave = p_clave $$;

-- ---------------------------------------------------------------------
-- Tablas y vistas que usa alguna app
-- ---------------------------------------------------------------------
create temp table _objetos (
  nombre   name primary key,
  es_vista boolean not null,
  apps     text not null
) on commit drop;
insert into _objetos values
  ('sucursales',              false, 'Flutter, Android, iOS'),
  ('telas',                   false, 'Flutter, Android, iOS'),
  ('tela_sucursales',         false, 'Flutter, Android, iOS'),
  ('colores',                 false, 'Flutter, Android, iOS'),
  ('tela_colores',            false, 'Flutter, Android, iOS'),
  ('aplique_colores',         false, 'Flutter, Android, iOS'),
  ('apliques',                false, 'Flutter, Android, iOS'),
  ('inventario',              false, 'Flutter, Android, iOS'),
  ('producciones',            false, 'Flutter, Android, iOS'),
  ('detalle_produccion',      false, 'Flutter, Android, iOS'),
  ('ventas',                  false, 'Flutter, Android, iOS'),
  ('detalle_ventas',          false, 'Flutter, Android, iOS'),
  ('ventas_apliques',         false, 'Flutter, Android'),
  ('detalle_ventas_apliques', false, 'Flutter, Android'),
  ('top_telas_web',           true,  'web'),
  ('sucursales_web',          true,  'web');

-- ---------------------------------------------------------------------
-- Columnas: lo que leen los mappers/DTO (las apps piden select * y leen
-- estas), lo que filtran u ordenan y lo que escriben.
--   tipo    = tipo base, sin precisión
--   no_nula = quién la decodifica como no nula (NULL = todas toleran null)
-- ---------------------------------------------------------------------
create temp table _columnas (
  objeto  name not null references _objetos,
  columna name not null,
  tipo    text not null,
  apps    text not null,
  no_nula text,
  primary key (objeto, columna)
) on commit drop;
insert into _columnas values
  -- sucursales: listados y form (escriben nombre; baja lógica por activo).
  -- Embebida en producciones(fecha, sucursales(nombre)). Lo que publica la
  -- web (slug, dirección, ubicación) va por sucursales_web.
  ('sucursales', 'id',     'bigint',  'Flutter, Android, iOS', 'Android: Int'),
  ('sucursales', 'nombre', 'text',    'Flutter, Android, iOS', 'Android: String'),
  ('sucursales', 'activo', 'boolean', 'Flutter, Android, iOS', 'Android: Boolean'),

  -- telas: catálogo, form y selector de la venta (filtra activo)
  ('telas', 'id',          'bigint',  'Flutter, Android, iOS', 'Android: Int'),
  ('telas', 'nombre',      'text',    'Flutter, Android, iOS', 'Android: String'),
  ('telas', 'precxmen',    'numeric', 'Flutter, Android, iOS', 'Android: Double'),
  ('telas', 'precxmay',    'numeric', 'Flutter, Android, iOS', 'Android: Double'),
  ('telas', 'precxrollo',  'numeric', 'Flutter, Android, iOS', 'Android: Double'),
  ('telas', 'precxcompra', 'numeric', 'Flutter, Android, iOS', 'Android: Double'),
  ('telas', 'activo',      'boolean', 'Flutter, Android, iOS', 'Android: Boolean'),

  -- tela_sucursales: disponibilidad por sucursal; embebida desde telas
  -- (tela_sucursales(activo) y tela_sucursales!inner(*)) y upsert por la PK
  ('tela_sucursales', 'idtela',     'bigint',  'Flutter, Android, iOS', 'Android: Int'),
  ('tela_sucursales', 'idsucursal', 'bigint',  'Flutter, Android, iOS', null),
  ('tela_sucursales', 'activo',     'boolean', 'Flutter, Android, iOS', 'Android: Boolean'),

  -- colores: gestión /colores y selectores; embebido en inventario y en
  -- detalle_produccion como colores(nombre, hex)
  ('colores', 'id',     'bigint',  'Flutter, Android, iOS', 'Android: Int; Flutter: as int'),
  ('colores', 'nombre', 'text',    'Flutter, Android, iOS', 'Android: String'),
  ('colores', 'hex',    'text',    'Flutter, Android, iOS', null),
  ('colores', 'activo', 'boolean', 'Flutter, Android, iOS', 'Android: Boolean'),

  -- tela_colores: colores de una tela; embebida desde colores y upsert por la PK
  ('tela_colores', 'idtela',  'bigint',  'Flutter, Android, iOS', null),
  ('tela_colores', 'idcolor', 'bigint',  'Flutter, Android, iOS', null),
  ('tela_colores', 'activo',  'boolean', 'Flutter, Android, iOS', 'Android: Boolean'),

  -- aplique_colores: colores de un aplique; embebida desde colores, upsert
  -- por la PK, y Flutter/Android cruzan (idaplique, idcolor) con el inventario
  ('aplique_colores', 'idaplique', 'bigint',  'Flutter, Android, iOS', 'Android: Int'),
  ('aplique_colores', 'idcolor',   'bigint',  'Flutter, Android, iOS', 'Android: Int'),
  ('aplique_colores', 'activo',    'boolean', 'Flutter, Android, iOS', 'Android: Boolean'),

  -- apliques: gestión y form (escriben nombre, medidas, costo y activo).
  -- tamanio ya no se usa en los forms, pero los tres mappers lo leen.
  ('apliques', 'id',                'bigint',  'Flutter, Android, iOS', 'Android: Int; Flutter: as int'),
  ('apliques', 'nombre',            'text',    'Flutter, Android, iOS', 'Android: String'),
  ('apliques', 'costo_fabricacion', 'numeric', 'Flutter, Android, iOS', 'Android: Double'),
  ('apliques', 'tamanio',           'text',    'Flutter, Android, iOS', null),
  ('apliques', 'ancho_cm',          'numeric', 'Flutter, Android, iOS', null),
  ('apliques', 'alto_cm',           'numeric', 'Flutter, Android, iOS', null),
  ('apliques', 'activo',            'boolean', 'Flutter, Android, iOS', 'Android: Boolean'),

  -- inventario: stock para la venta y Fabricación; alta/baja lógica de filas
  ('inventario', 'sucursal_id', 'bigint',  'Flutter, Android, iOS', null),
  ('inventario', 'aplique_id',  'bigint',  'Flutter, Android, iOS', 'Android: Int; Flutter: as int'),
  ('inventario', 'color_id',    'bigint',  'Flutter, Android, iOS', 'Android: Int; Flutter: as int'),
  ('inventario', 'stock',       'numeric', 'Flutter, Android, iOS', 'Android: Double'),
  ('inventario', 'activo',      'boolean', 'Flutter, Android, iOS', 'Android: Boolean'),

  -- producciones: historial de Fabricación (Flutter y Android); iOS solo la
  -- lee embebida desde detalle_produccion. fecha es DATE ('yyyy-MM-dd').
  ('producciones', 'id',          'bigint', 'Flutter, Android',      'Android: Int; Flutter: as int'),
  ('producciones', 'fecha',       'date',   'Flutter, Android, iOS', null),
  ('producciones', 'sucursal_id', 'bigint', 'Flutter, Android',      null),

  -- detalle_produccion: líneas de una fabricación (con apliques, colores y
  -- producciones embebidos; ver las FK más abajo)
  ('detalle_produccion', 'id',           'bigint',  'Flutter, Android, iOS', 'Android: Int; Flutter: as int'),
  ('detalle_produccion', 'idproduccion', 'bigint',  'Flutter, Android',      null),
  ('detalle_produccion', 'cantidad',     'numeric', 'Flutter, Android, iOS', 'Android: Double'),

  -- ventas (solo telas): fecha es TEXT ISO8601 porque las tres apps buscan
  -- la del día con like 'yyyy-MM-dd%' (con date/timestamp el like falla)
  ('ventas', 'id',           'bigint',  'Flutter, Android, iOS', 'Android: Int; Flutter: as int'),
  ('ventas', 'fecha',        'text',    'Flutter, Android, iOS', 'Android: String'),
  ('ventas', 'total',        'numeric', 'Flutter, Android, iOS', 'Android: Double'),
  ('ventas', 'ganancias',    'numeric', 'Flutter, Android, iOS', 'Android: Double'),
  ('ventas', 'descuento',    'numeric', 'Flutter, Android, iOS', 'Android: Double'),
  ('ventas', 'idsucursales', 'bigint',  'Flutter, Android, iOS', 'Android: Int; Flutter: as int'),

  -- detalle_ventas: líneas de la venta de telas (y lo que devuelve
  -- registrar_detalle_venta). total y ganancias pueden ser NULL para todas.
  ('detalle_ventas', 'id',        'bigint',  'Flutter, Android, iOS', 'Android: Int'),
  ('detalle_ventas', 'nombre',    'text',    'Flutter, Android, iOS', null),
  ('detalle_ventas', 'precio',    'numeric', 'Flutter, Android, iOS', 'Android: Double'),
  ('detalle_ventas', 'cantidad',  'numeric', 'Flutter, Android, iOS', 'Android: Double'),
  ('detalle_ventas', 'total',     'numeric', 'Flutter, Android, iOS', null),
  ('detalle_ventas', 'ganancias', 'numeric', 'Flutter, Android, iOS', null),
  ('detalle_ventas', 'idtelas',   'bigint',  'Flutter, Android, iOS', 'Android: Int; Flutter: as int'),
  ('detalle_ventas', 'idventa',   'bigint',  'Flutter, Android, iOS', 'Android: Int'),

  -- ventas_apliques: historial de la venta de apliques (iOS solo vende por RPC)
  ('ventas_apliques', 'id',           'bigint', 'Flutter, Android', 'Android: Int; Flutter: as int'),
  ('ventas_apliques', 'fecha',        'text',   'Flutter, Android', null),
  ('ventas_apliques', 'idsucursales', 'bigint', 'Flutter, Android', null),

  -- detalle_ventas_apliques: detalle de la venta del día
  ('detalle_ventas_apliques', 'id',       'bigint',  'Flutter, Android', 'Android: Int; Flutter: as int'),
  ('detalle_ventas_apliques', 'idventa',  'bigint',  'Flutter, Android', null),
  ('detalle_ventas_apliques', 'nombre',   'text',    'Flutter, Android', null),
  ('detalle_ventas_apliques', 'precio',   'numeric', 'Flutter, Android', 'Android: Double'),
  ('detalle_ventas_apliques', 'cantidad', 'numeric', 'Flutter, Android', 'Android: Double'),
  ('detalle_ventas_apliques', 'total',    'numeric', 'Flutter, Android', 'Android: Double'),

  -- top_telas_web: "las más buscadas" de la landing (select *, order posicion;
  -- normaliza los numeric con Number())
  ('top_telas_web', 'posicion',     'bigint',  'web', null),
  ('top_telas_web', 'id',           'bigint',  'web', null),
  ('top_telas_web', 'nombre',       'text',    'web', null),
  ('top_telas_web', 'slug',         'text',    'web', null),
  ('top_telas_web', 'descripcion',  'text',    'web', null),
  ('top_telas_web', 'ancho',        'numeric', 'web', null),
  ('top_telas_web', 'precio_metro', 'numeric', 'web', null),
  ('top_telas_web', 'precio_mayor', 'numeric', 'web', null),
  ('top_telas_web', 'precio_rollo', 'numeric', 'web', null),
  ('top_telas_web', 'foto',         'text',    'web', null),

  -- sucursales_web: tarjetas de sucursal (select *, order id). latitud y
  -- longitud son texto: arma el link de Google Maps con "lat,lng"
  ('sucursales_web', 'id',        'bigint', 'web', null),
  ('sucursales_web', 'nombre',    'text',   'web', null),
  ('sucursales_web', 'slug',      'text',   'web', null),
  ('sucursales_web', 'direccion', 'text',   'web', null),
  ('sucursales_web', 'latitud',   'text',   'web', null),
  ('sucursales_web', 'longitud',  'text',   'web', null);

-- ---------------------------------------------------------------------
-- Embeds: PostgREST resuelve cada uno por la FK entre las dos tablas
-- ---------------------------------------------------------------------
create temp table _embeds (
  hija    name not null,
  columna name not null,
  madre   name not null,
  embed   text not null,
  apps    text not null
) on commit drop;
insert into _embeds values
  ('tela_sucursales',    'idtela',       'telas',        'telas → tela_sucursales(activo) / tela_sucursales!inner(*)', 'Flutter, Android, iOS'),
  ('tela_colores',       'idcolor',      'colores',      'colores → tela_colores(activo)',                             'Flutter, Android, iOS'),
  ('aplique_colores',    'idcolor',      'colores',      'colores → aplique_colores(activo)',                          'Flutter, Android, iOS'),
  ('inventario',         'color_id',     'colores',      'inventario → colores(nombre, hex)',                          'Flutter, Android, iOS'),
  ('detalle_produccion', 'idaplique',    'apliques',     'detalle_produccion → apliques(nombre)',                      'Flutter, Android, iOS'),
  ('detalle_produccion', 'idcolor',      'colores',      'detalle_produccion → colores(nombre, hex)',                  'Flutter, Android, iOS'),
  ('detalle_produccion', 'idproduccion', 'producciones', 'detalle_produccion → producciones(fecha, ...)',              'Flutter, Android, iOS'),
  ('producciones',       'sucursal_id',  'sucursales',   'producciones → sucursales(nombre)',                          'Flutter, Android, iOS');

-- ---------------------------------------------------------------------
-- Inserts directos por PostgREST (los de las RPC no cuentan): columnas que
-- mandan las apps. Upserts incluidos.
-- ---------------------------------------------------------------------
create temp table _inserts (
  tabla    name primary key,
  columnas name[] not null,
  apps     text not null
) on commit drop;
insert into _inserts values
  ('sucursales',      array['nombre'],                                                          'Flutter, Android, iOS'),
  ('telas',           array['nombre', 'precxmen', 'precxmay', 'precxrollo', 'precxcompra', 'activo'], 'Flutter, Android, iOS'),
  ('colores',         array['nombre', 'hex'],                                                   'Flutter, Android, iOS'),
  ('apliques',        array['nombre', 'ancho_cm', 'alto_cm', 'costo_fabricacion', 'activo'],    'Flutter, Android, iOS'),
  ('tela_sucursales', array['idtela', 'idsucursal', 'activo'],                                  'Flutter, Android, iOS'),
  ('tela_colores',    array['idtela', 'idcolor', 'activo'],                                     'Flutter, Android, iOS'),
  ('aplique_colores', array['idaplique', 'idcolor', 'activo'],                                  'Flutter, Android, iOS'),
  ('inventario',      array['sucursal_id', 'aplique_id', 'color_id', 'stock'],                  'Flutter, Android, iOS'),
  ('ventas',          array['fecha', 'total', 'ganancias', 'descuento', 'idsucursales'],        'Flutter, Android, iOS');

-- ---------------------------------------------------------------------
-- RPC: firma tal como la llaman las apps (todas mandan todos los
-- parámetros por nombre, así que los DEFAULT no son parte del contrato)
-- ---------------------------------------------------------------------
create temp table _rpcs (
  nombre     name primary key,
  tipos      name[] not null,
  argumentos text not null,  -- pg_get_function_identity_arguments
  resultado  text not null,  -- pg_get_function_result
  apps       text not null
) on commit drop;
insert into _rpcs values
  ('crear_venta_apliques', array['bigint', 'text', 'numeric', 'numeric', 'numeric', 'jsonb'],
   'p_idsucursales bigint, p_fecha text, p_total numeric, p_ganancias numeric, p_descuento numeric, p_detalles jsonb',
   'bigint', 'Flutter, Android, iOS'),
  ('registrar_produccion', array['bigint', 'date', 'jsonb'],
   'p_sucursal_id bigint, p_fecha date, p_lineas jsonb',
   'bigint', 'Flutter, Android, iOS'),
  ('registrar_detalle_venta', array['bigint', 'jsonb'],
   'p_idventa bigint, p_detalles jsonb',
   'SETOF detalle_ventas', 'Flutter, Android, iOS'),
  ('incrementar_venta', array['bigint', 'numeric', 'numeric', 'numeric', 'text'],
   'p_id bigint, p_total numeric, p_ganancias numeric, p_descuento numeric, p_fecha text',
   'ventas', 'Flutter, Android, iOS'),
  ('top_productos', array['text', 'text'],
   'desde text, hasta text',
   'TABLE(nombre text, total_vendido numeric, total_cantidad numeric)', 'Flutter, Android, iOS'),
  ('top_apliques', array['text', 'text'],
   'desde text, hasta text',
   'TABLE(nombre text, total_vendido numeric, total_cantidad numeric)', 'Flutter, Android'),
  ('resumen_ventas', array['text', 'text'],
   'desde text, hasta text',
   'TABLE(total numeric, ganancias numeric, descuento numeric)', 'Flutter, Android, iOS'),
  ('resumen_ventas_apliques', array['text', 'text'],
   'desde text, hasta text',
   'TABLE(total numeric, ganancias numeric, descuento numeric)', 'Flutter, Android, iOS'),
  ('inventario_con_ventas', array['bigint', 'text', 'text'],
   'p_sucursal_id bigint, desde text, hasta text',
   'TABLE(aplique_id bigint, aplique text, color_id bigint, color text, hex text, stock numeric, vendidas numeric, vendidas_otras numeric)',
   'Flutter');

-- =====================================================================
-- 1. Tablas, vistas y columnas (16 + 80 + 80 + 46)
-- =====================================================================
select has_table('public', nombre, format('existe la tabla %s (la usan %s)', nombre, apps))
from _objetos where not es_vista order by nombre;

select has_view('public', nombre, format('existe la vista %s (la usa la %s)', nombre, apps))
from _objetos where es_vista order by nombre;

select has_column('public', objeto, columna, format('%s.%s existe (la usan %s)', objeto, columna, apps))
from _columnas order by objeto, columna;

select is(
  (select format_type(a.atttypid, null)
     from pg_attribute a
    where a.attrelid = to_regclass(format('public.%I', c.objeto))
      and a.attname = c.columna and a.attnum > 0 and not a.attisdropped),
  c.tipo,
  format('%s.%s es %s (la usan %s)', c.objeto, c.columna, c.tipo, c.apps))
from _columnas c order by c.objeto, c.columna;

select col_not_null('public', objeto, columna,
  format('%s.%s es NOT NULL (%s: un null rompe el decode)', objeto, columna, no_nula))
from _columnas where no_nula is not null order by objeto, columna;

-- =====================================================================
-- 2. Embeds y upserts (8 + 1 + 3)
-- =====================================================================
select fk_ok('public', hija, columna, 'public', madre, 'id',
  format('FK %s.%s → %s.id: la necesita el embed %s (%s)', hija, columna, madre, embed, apps))
from _embeds order by hija, columna;

select is_empty($$
  select e.hija, e.madre, count(*)
  from (select distinct hija, madre from _embeds) e
  join pg_constraint c on c.contype = 'f'
   and ((c.conrelid = to_regclass('public.' || e.hija) and c.confrelid = to_regclass('public.' || e.madre))
     or (c.conrelid = to_regclass('public.' || e.madre) and c.confrelid = to_regclass('public.' || e.hija)))
  group by e.hija, e.madre
  having count(*) > 1
$$, 'cada embed tiene una sola FK entre sus dos tablas (con dos, PostgREST responde PGRST201: relación ambigua)');

-- El upsert de PostgREST resuelve el conflicto por la PK (las apps no mandan on_conflict)
select col_is_pk('public', 'tela_sucursales', array['idtela', 'idsucursal']::name[],
  'tela_sucursales: PK (idtela, idsucursal), la del upsert de la disponibilidad (Flutter, Android, iOS)');
select col_is_pk('public', 'tela_colores', array['idtela', 'idcolor']::name[],
  'tela_colores: PK (idtela, idcolor), la del upsert de los colores de la tela (Flutter, Android, iOS)');
select col_is_pk('public', 'aplique_colores', array['idaplique', 'idcolor']::name[],
  'aplique_colores: PK (idaplique, idcolor), la del upsert de los colores del aplique (Flutter, Android, iOS)');

-- =====================================================================
-- 3. Inserts: una columna NOT NULL nueva sin default rompe el alta en las
--    apps que no la mandan (9)
-- =====================================================================
select is_empty(
  format($q$
    select a.attname
    from pg_attribute a
    left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
    where a.attrelid = to_regclass(%L) and a.attnum > 0 and not a.attisdropped
      and a.attnotnull and d.oid is null and a.attidentity = '' and a.attgenerated = ''
      and a.attname <> all (%L::name[])
  $q$, 'public.' || tabla, columnas),
  format('%s: toda columna NOT NULL sin default está entre las que mandan %s al insertar (%s)',
         tabla, apps, array_to_string(columnas, ', ')))
from _inserts order by tabla;

-- =====================================================================
-- 4. RPC: existencia, nombres de los parámetros y resultado (9 + 9 + 9)
-- =====================================================================
select has_function('public', nombre, tipos,
  format('existe la RPC %s(%s) (la llaman %s)', nombre, array_to_string(tipos, ', '), apps))
from _rpcs order by nombre;

select is(
  (select string_agg(pg_get_function_identity_arguments(p.oid), ' | ')
     from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.proname = r.nombre),
  r.argumentos,
  format('%s: parámetros (%s) — PostgREST llama por nombre (%s)', r.nombre, r.argumentos, r.apps))
from _rpcs r order by r.nombre;

select is(
  (select string_agg(pg_get_function_result(p.oid), ' | ')
     from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.proname = r.nombre),
  r.resultado,
  format('%s devuelve %s (%s lo decodifican)', r.nombre, r.resultado, r.apps))
from _rpcs r order by r.nombre;

-- ---------------------------------------------------------------------
-- Claves del JSON: se llama como PostgREST (argumentos nombrados) con el
-- mismo objeto que arman Flutter, Android e iOS, y cada clave tiene que
-- llegar a su columna (4 llamadas + 4 verificaciones).
-- Las llamadas van en lives_ok y los datos de apoyo atrapan su error: si
-- una migración rompe algo, los tests de acá fallan uno por uno en vez de
-- abortar la transacción y tapar el resto.
-- ---------------------------------------------------------------------
do $$
declare
  v_sucursal bigint; v_color bigint; v_aplique bigint;
  v_tela bigint; v_tela_sin_total bigint; v_venta bigint;
begin
  insert into public.sucursales (nombre) values ('pgTAP Contrato') returning id into v_sucursal;
  insert into public.colores (nombre, hex) values ('pgTAP Contrato rojo', '#FF0000') returning id into v_color;
  insert into public.apliques (nombre, costo_fabricacion) values ('pgTAP Contrato mariposa', 4)
    returning id into v_aplique;
  insert into public.aplique_colores (idaplique, idcolor) values (v_aplique, v_color);
  insert into public.telas (nombre, precxmen, precxcompra) values ('pgTAP Contrato lino', 10, 7)
    returning id into v_tela;
  insert into public.telas (nombre, precxmen, precxcompra) values ('pgTAP Contrato seda', 20, 12)
    returning id into v_tela_sin_total;
  insert into public.ventas (fecha, idsucursales) values ('2187-03-10T09:00:00.000', v_sucursal)
    returning id into v_venta;

  insert into pg_temp._ids values
    ('sucursal', v_sucursal), ('color', v_color), ('aplique', v_aplique),
    ('tela', v_tela), ('tela_sin_total', v_tela_sin_total), ('venta', v_venta);
exception when others then
  raise warning 'no se pudieron crear los datos de apoyo: %', sqlerrm;
end
$$;

select lives_ok($$
  select public.registrar_produccion(
    p_sucursal_id => pg_temp.id('sucursal'),
    p_fecha       => '2187-03-10',
    p_lineas      => jsonb_build_array(jsonb_build_object(
      'idaplique', pg_temp.id('aplique'),
      'idcolor',   pg_temp.id('color'),
      'cantidad',  5)))
$$, 'registrar_produccion acepta p_lineas [{idaplique, idcolor, cantidad}] por nombre');

select results_eq($$
  select d.idaplique, d.idcolor, d.cantidad, i.stock
  from public.producciones p
  join public.detalle_produccion d on d.idproduccion = p.id
  join public.inventario i on i.sucursal_id = p.sucursal_id
   and i.aplique_id = d.idaplique and i.color_id = d.idcolor
  where p.sucursal_id = pg_temp.id('sucursal')
$$, $$ values (pg_temp.id('aplique'), pg_temp.id('color'), 5::numeric, 5::numeric) $$,
'registrar_produccion: idaplique, idcolor y cantidad llegan a la línea y al stock');

select lives_ok($$
  select public.crear_venta_apliques(
    p_idsucursales => pg_temp.id('sucursal'),
    p_fecha        => '2187-03-10T10:00:00.000',
    p_total        => 20,
    p_ganancias    => 12,
    p_descuento    => 0,
    p_detalles     => jsonb_build_array(jsonb_build_object(
      'idapliques', pg_temp.id('aplique'),
      'idcolor',    pg_temp.id('color'),
      'nombre',     'pgTAP Contrato mariposa (rojo)',
      'precio',     10,
      'cantidad',   2,
      'total',      20,
      'ganancias',  12)))
$$, 'crear_venta_apliques acepta p_detalles [{idapliques, idcolor, nombre, precio, cantidad, total, ganancias}] por nombre');

select results_eq($$
  select d.idapliques, d.idcolor, d.nombre, d.precio, d.cantidad, d.total, d.ganancias, i.stock
  from public.ventas_apliques v
  join public.detalle_ventas_apliques d on d.idventa = v.id
  join public.inventario i on i.sucursal_id = v.idsucursales
   and i.aplique_id = d.idapliques and i.color_id = d.idcolor
  where v.idsucursales = pg_temp.id('sucursal')
$$, $$ values (pg_temp.id('aplique'), pg_temp.id('color'), 'pgTAP Contrato mariposa (rojo)',
               10::numeric, 2::numeric, 20::numeric, 12::numeric, 3::numeric) $$,
'crear_venta_apliques: cada clave llega a su columna y descuenta el stock');

select lives_ok($$
  select * from public.registrar_detalle_venta(
    p_idventa  => pg_temp.id('venta'),
    p_detalles => jsonb_build_array(jsonb_build_object(
      'idtelas',   pg_temp.id('tela'),
      'nombre',    'pgTAP Contrato lino',
      'precio',    10,
      'cantidad',  1.5,
      'total',     15,
      'ganancias', 4.5)))
$$, 'registrar_detalle_venta acepta p_detalles [{idtelas, nombre, precio, cantidad, total, ganancias}] por nombre');

select results_eq($$
  select idtelas, nombre, precio, cantidad, total, ganancias
  from public.detalle_ventas where idventa = pg_temp.id('venta')
$$, $$ values (pg_temp.id('tela'), 'pgTAP Contrato lino', 10::numeric, 1.5::numeric,
               15::numeric, 4.5::numeric) $$,
'registrar_detalle_venta: cada clave llega a su columna');

-- Las tres apps mandan p_fecha aunque sea null (Flutter y Android: null
-- cuando no cambia la fecha)
select lives_ok($$
  select * from public.incrementar_venta(
    p_id        => pg_temp.id('venta'),
    p_total     => 15,
    p_ganancias => 4.5,
    p_descuento => 0,
    p_fecha     => null)
$$, 'incrementar_venta acepta p_id, p_total, p_ganancias, p_descuento y p_fecha (null) por nombre');

select results_eq($$
  select fecha, total, ganancias, descuento
  from public.ventas where id = pg_temp.id('venta')
$$, $$ values ('2187-03-10T09:00:00.000', 15::numeric, 4.5::numeric, 0::numeric) $$,
'incrementar_venta: suma los deltas y p_fecha null no toca la fecha');

-- ---------------------------------------------------------------------
-- Lo que Android decodifica como no nulo en el resultado de una RPC (1)
-- ---------------------------------------------------------------------
-- Una línea de telas sin total: hoy la base la acepta (la columna admite
-- NULL y registrar_detalle_venta también, si el JSON no trae "total").
-- Si se arregla con NOT NULL, el insert falla y el test sigue valiendo.
do $$
begin
  insert into public.detalle_ventas (nombre, precio, cantidad, total, ganancias, idtelas, idventa)
  values ('pgTAP Contrato seda', 20, 1, null, null, pg_temp.id('tela_sin_total'), pg_temp.id('venta'));
exception when others then
  null;
end
$$;

select todo('bug: 20261003000100_integridad_stock_y_ventas.sql:249 — top_productos hace SUM(dv.total) y detalle_ventas.total admite NULL: una tela cuyas líneas del rango no tienen total sale con total_vendido NULL, y Android (dto/TopProductoRow.kt:8, total_vendido: Double) no la puede decodificar y el dashboard de telas entero falla. Hoy no hay ninguna línea con total NULL; se arregla con COALESCE en la RPC o con detalle_ventas.total/ganancias NOT NULL', 1);
select is_empty($$
  select nombre, total_vendido, total_cantidad
  from public.top_productos('2187-03-10T00:00:00', '2187-03-10T23:59:59.999999')
  where total_vendido is null or total_cantidad is null
$$, 'top_productos nunca devuelve total_vendido ni total_cantidad NULL (Android los decodifica como Double)');

select * from finish();
rollback;
