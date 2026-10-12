-- =====================================================================
-- Vistas públicas de la landing (supabase/landing.sql y
-- 20261003000000_vistas_catalogo_web.sql)
--
--   * top_telas_web: top 6 por monto vendido histórico, agrupado por
--     idtelas; publica `posicion`, nunca el monto ni precxcompra; precio 0
--     sale NULL; no publica telas inactivas ni sin ningún precio;
--   * sucursales_web: solo activo = true;
--   * catalogo_telas_web / catalogo_apliques_web: solo activos, sin
--     precxcompra ni costo_fabricacion; colores = vínculos y colores activos.
--
-- Se leen como anon (la web): funcionan aunque anon no tenga acceso a las
-- tablas. Rollback al final.
-- =====================================================================
begin;
select plan(18);

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
  v_activa bigint; v_cerrada bigint;
  v_rojo bigint; v_amarillo bigint; v_azul bigint; v_verde bigint;
  v_lino bigint; v_seda bigint; v_sin_precio bigint; v_tela_inactiva bigint;
  v_mariposa bigint; v_aplique_inactivo bigint; v_venta bigint;
begin
  insert into public.sucursales (nombre, slug, direccion, latitud, longitud)
    values ('pgTAP Centro', 'pgtap-centro', 'pgTAP calle 1', '-17.78', '-63.18') returning id into v_activa;
  insert into public.sucursales (nombre, slug, activo)
    values ('pgTAP Cerrada', 'pgtap-cerrada', false) returning id into v_cerrada;

  insert into public.colores (nombre, hex) values ('pgTAP Rojo', '#FF0000') returning id into v_rojo;
  insert into public.colores (nombre, hex) values ('pgTAP amarillo', '#FFFF00') returning id into v_amarillo;
  insert into public.colores (nombre, hex, activo) values ('pgTAP Azul', '#0000FF', false) returning id into v_azul;
  insert into public.colores (nombre, hex) values ('pgTAP Verde', '#00FF00') returning id into v_verde;

  insert into public.telas (nombre, slug, descripcion, ancho, precxmen, precxmay, precxrollo, precxcompra)
    values ('pgTAP Top Lino', 'pgtap-top-lino', 'pgTAP lino lavado', 1.50, 10, 0, 300, 7) returning id into v_lino;
  insert into public.telas (nombre, slug, precxmen, precxmay, precxrollo, precxcompra)
    values ('pgTAP Top Seda', 'pgtap-top-seda', 0, 0, 500, 350) returning id into v_seda;
  insert into public.telas (nombre, precxmen, precxmay, precxrollo, precxcompra)
    values ('pgTAP Sin precio', 0, 0, 0, 5) returning id into v_sin_precio;
  insert into public.telas (nombre, precxmen, activo)
    values ('pgTAP Inactiva', 20, false) returning id into v_tela_inactiva;

  -- La primera foto (por id) está dada de baja: se publica la siguiente
  insert into public.tela_fotos (idtela, url, activo) values
    (v_lino, 'https://example.com/pgtap-vieja.jpg', false),
    (v_lino, 'https://example.com/pgtap-a.jpg', true),
    (v_lino, 'https://example.com/pgtap-b.jpg', true);

  -- Rojo y amarillo publicados; azul (color inactivo) y verde (vínculo inactivo) no
  insert into public.tela_colores (idtela, idcolor, activo) values
    (v_lino, v_rojo, true), (v_lino, v_amarillo, true),
    (v_lino, v_azul, true), (v_lino, v_verde, false);

  insert into public.apliques (nombre, tamanio, ancho_cm, alto_cm, costo_fabricacion)
    values ('pgTAP Mariposa', '10x8', 10, 8, 6) returning id into v_mariposa;
  insert into public.apliques (nombre, activo)
    values ('pgTAP Aplique viejo', false) returning id into v_aplique_inactivo;
  insert into public.aplique_colores (idaplique, idcolor, activo) values
    (v_mariposa, v_verde, true), (v_mariposa, v_rojo, false), (v_mariposa, v_azul, true);

  -- Montos enormes para entrar al top 6 por encima de las ventas reales.
  -- Lino vende 7e11 en dos líneas con distinto nombre (agrupado por nombre
  -- quedarían por debajo de Seda); sin precio e inactiva venden más pero
  -- no se publican.
  insert into public.ventas (fecha, idsucursales) values ('2187-03-10T10:00:00.000', v_activa)
    returning id into v_venta;
  insert into public.detalle_ventas (nombre, precio, cantidad, total, ganancias, idtelas, idventa) values
    ('Lino viejo', 9,   1, 400000000000, 0, v_lino, v_venta),
    ('Lino nuevo', 10,  1, 300000000000, 0, v_lino, v_venta),
    ('Seda',       500, 1, 500000000000, 0, v_seda, v_venta),
    ('Sin precio', 1,   1, 900000000000, 0, v_sin_precio, v_venta),
    ('Inactiva',   20,  1, 950000000000, 0, v_tela_inactiva, v_venta);

  insert into pg_temp._ids values
    ('activa', v_activa), ('cerrada', v_cerrada),
    ('lino', v_lino), ('seda', v_seda), ('sin_precio', v_sin_precio), ('tela_inactiva', v_tela_inactiva),
    ('mariposa', v_mariposa), ('aplique_inactivo', v_aplique_inactivo);
end
$$;

set local role anon;
set local request.jwt.claims = '{"role": "anon"}';

-- =====================================================================
-- top_telas_web
-- =====================================================================
select columns_are('public', 'top_telas_web', array[
  'posicion', 'id', 'nombre', 'slug', 'descripcion', 'ancho',
  'precio_metro', 'precio_mayor', 'precio_rollo', 'foto'
]::name[], 'top_telas_web publica la posición, no el monto vendido');
select hasnt_column('public', 'top_telas_web', 'precxcompra', 'top_telas_web no expone precxcompra');
select hasnt_column('public', 'top_telas_web', 'monto', 'top_telas_web no expone el monto del ranking');

select results_eq($$
  select posicion, id, nombre, slug, descripcion, ancho, precio_metro, precio_mayor, precio_rollo, foto
  from public.top_telas_web
  where id in (pg_temp.id('lino'), pg_temp.id('seda'))
  order by posicion
$$, $$ values
  (1::bigint, pg_temp.id('lino'), 'pgTAP Top Lino', 'pgtap-top-lino', 'pgTAP lino lavado', 1.50::numeric,
   10::numeric, null::numeric, 300::numeric, 'https://example.com/pgtap-a.jpg'),
  (2::bigint, pg_temp.id('seda'), 'pgTAP Top Seda', 'pgtap-top-seda', null::text, null::numeric,
   null::numeric, null::numeric, 500::numeric, null::text)
$$, 'top_telas_web: ordena por monto histórico sumado por idtelas, precio 0 → NULL, foto = primera foto activa');

select results_eq(
  $$ select count(*) from public.top_telas_web where id = pg_temp.id('lino') $$,
  array[1::bigint],
  'top_telas_web: una tela con líneas de distinto nombre aparece una sola vez'
);

select is_empty($$
  select 1 from public.top_telas_web
  where id in (pg_temp.id('sin_precio'), pg_temp.id('tela_inactiva'))
$$, 'top_telas_web: no publica telas sin ningún precio ni inactivas, aunque vendan más');

select ok((select count(*) from public.top_telas_web) <= 6, 'top_telas_web: publica como máximo 6 telas');

-- =====================================================================
-- sucursales_web
-- =====================================================================
select columns_are('public', 'sucursales_web', array[
  'id', 'nombre', 'slug', 'direccion', 'latitud', 'longitud'
]::name[], 'sucursales_web publica nombre, slug, dirección y ubicación');

select results_eq($$
  select id, nombre, slug, direccion, latitud, longitud from public.sucursales_web
  where id = pg_temp.id('activa')
$$, $$ values (pg_temp.id('activa'), 'pgTAP Centro', 'pgtap-centro', 'pgTAP calle 1', '-17.78', '-63.18') $$,
'sucursales_web: publica la sucursal activa');

select is_empty(
  $$ select 1 from public.sucursales_web where id = pg_temp.id('cerrada') $$,
  'sucursales_web: no publica una sucursal dada de baja (activo = false)'
);

-- =====================================================================
-- catalogo_telas_web
-- =====================================================================
select columns_are('public', 'catalogo_telas_web', array[
  'id', 'nombre', 'slug', 'descripcion', 'ancho',
  'precio_metro', 'precio_mayor', 'precio_rollo', 'foto', 'colores'
]::name[], 'catalogo_telas_web publica datos de vitrina');
select hasnt_column('public', 'catalogo_telas_web', 'precxcompra', 'catalogo_telas_web no expone precxcompra');

select results_eq($$
  select id, precio_metro, precio_mayor, precio_rollo, foto, colores
  from public.catalogo_telas_web
  where id in (pg_temp.id('lino'), pg_temp.id('seda'), pg_temp.id('sin_precio'))
  order by nombre
$$, $$ values
  (pg_temp.id('sin_precio'), null::numeric, null::numeric, null::numeric, null::text, '[]'::jsonb),
  (pg_temp.id('lino'), 10::numeric, null::numeric, 300::numeric, 'https://example.com/pgtap-a.jpg',
   '[{"nombre": "pgTAP amarillo", "hex": "#FFFF00"}, {"nombre": "pgTAP Rojo", "hex": "#FF0000"}]'::jsonb),
  (pg_temp.id('seda'), null::numeric, null::numeric, 500::numeric, null::text, '[]'::jsonb)
$$, 'catalogo_telas_web: también telas sin precio, precio 0 → NULL, solo colores activos con vínculo activo (orden sin mayúsculas)');

select is_empty(
  $$ select 1 from public.catalogo_telas_web where id = pg_temp.id('tela_inactiva') $$,
  'catalogo_telas_web: no publica telas inactivas'
);

-- =====================================================================
-- catalogo_apliques_web
-- =====================================================================
select columns_are('public', 'catalogo_apliques_web', array[
  'id', 'nombre', 'tamanio', 'ancho_cm', 'alto_cm', 'colores'
]::name[], 'catalogo_apliques_web publica datos de vitrina');
select hasnt_column('public', 'catalogo_apliques_web', 'costo_fabricacion', 'catalogo_apliques_web no expone costo_fabricacion');

select results_eq($$
  select id, nombre, tamanio, ancho_cm, alto_cm, colores
  from public.catalogo_apliques_web where id = pg_temp.id('mariposa')
$$, $$ values
  (pg_temp.id('mariposa'), 'pgTAP Mariposa', '10x8', 10::numeric, 8::numeric,
   '[{"nombre": "pgTAP Verde", "hex": "#00FF00"}]'::jsonb)
$$, 'catalogo_apliques_web: publica el aplique activo solo con sus colores habilitados y activos');

select is_empty(
  $$ select 1 from public.catalogo_apliques_web where id = pg_temp.id('aplique_inactivo') $$,
  'catalogo_apliques_web: no publica apliques inactivos'
);

reset role;

select * from finish();
rollback;
