-- =====================================================================
-- RLS y permisos
--
-- Regla (migraciones 20261003000100_integridad_stock_y_ventas.sql y
-- 20261004000000_solo_usuarios_logueados.sql):
--   * toda tabla de public tiene RLS y su política solo_logueados_<tabla>
--     (FOR ALL TO authenticated USING true WITH CHECK true);
--   * anon (la web, sin login) no lee ni escribe tablas ni ejecuta RPC:
--     solo lee las vistas *_web;
--   * authenticated lee y escribe todo, pero sin DELETE físico salvo en
--     ventas y detalle_ventas, y sin TRUNCATE en nada.
--
-- Corre en una transacción con rollback: no deja datos.
-- =====================================================================
begin;
select plan(189);

-- ---------------------------------------------------------------------
-- Datos de apoyo (solo viven en esta transacción)
-- ---------------------------------------------------------------------
create temp table _ids (clave text primary key, id bigint not null) on commit drop;
grant all on _ids to public;
create function pg_temp.id(p_clave text) returns bigint
  language sql stable
  as $$ select id from pg_temp._ids where clave = p_clave $$;

-- Las 16 tablas conocidas. Por cada una: cómo encontrar la fila que crea
-- este test y un cambio que authenticated tiene que poder hacer (el mismo
-- texto sirve de SET y de WHERE para verificarlo).
create temp table _tablas (
  nombre text primary key,
  filtro text not null,
  cambio text not null
) on commit drop;
grant select on _tablas to public;
insert into _tablas values
  ('aplique_colores',         $f$idaplique = pg_temp.id('aplique')$f$,      'activo = false'),
  ('apliques',                $f$id = pg_temp.id('aplique')$f$,             'activo = false'),
  ('categorias',              $f$id = pg_temp.id('categoria')$f$,           'activo = false'),
  ('colores',                 $f$id = pg_temp.id('color')$f$,               'activo = false'),
  ('detalle_produccion',      $f$idproduccion = pg_temp.id('produccion')$f$, 'cantidad = 7'),
  ('detalle_ventas',          $f$idventa = pg_temp.id('venta')$f$,          'cantidad = 7'),
  ('detalle_ventas_apliques', $f$idventa = pg_temp.id('venta_aplique')$f$,  'cantidad = 7'),
  ('inventario',              $f$sucursal_id = pg_temp.id('sucursal')$f$,   'stock = 7'),
  ('producciones',            $f$id = pg_temp.id('produccion')$f$,          $c$fecha = '2187-03-11'$c$),
  ('sucursales',              $f$id = pg_temp.id('sucursal')$f$,            'activo = false'),
  ('tela_colores',            $f$idtela = pg_temp.id('tela')$f$,            'activo = false'),
  ('tela_fotos',              $f$idtela = pg_temp.id('tela')$f$,            'activo = false'),
  ('tela_sucursales',         $f$idtela = pg_temp.id('tela')$f$,            'activo = false'),
  ('telas',                   $f$id = pg_temp.id('tela')$f$,                'activo = false'),
  ('ventas',                  $f$id = pg_temp.id('venta')$f$,               'total = 7'),
  ('ventas_apliques',         $f$id = pg_temp.id('venta_aplique')$f$,       'total = 7');

-- Las RPC que llaman las apps, con una llamada de ejemplo
create temp table _rpc (firma regprocedure primary key, llamada text not null) on commit drop;
grant select on _rpc to public;
insert into _rpc values
  ('public.crear_venta_apliques(bigint,text,numeric,numeric,numeric,jsonb)',
   $q$select public.crear_venta_apliques(1, '2187-01-01T10:00:00', 1, 0, 0, '[{"idapliques":1,"idcolor":1,"nombre":"x","precio":1,"cantidad":1,"total":1,"ganancias":0}]')$q$),
  ('public.registrar_produccion(bigint,date,jsonb)',
   $q$select public.registrar_produccion(1, '2187-01-01', '[{"idaplique":1,"idcolor":1,"cantidad":1}]')$q$),
  ('public.registrar_detalle_venta(bigint,jsonb)',
   $q$select * from public.registrar_detalle_venta(1, '[{"idtelas":1,"nombre":"x","precio":1,"cantidad":1,"total":1,"ganancias":0}]')$q$),
  ('public.incrementar_venta(bigint,numeric,numeric,numeric,text)',
   $q$select public.incrementar_venta(1, 1)$q$),
  ('public.top_productos(text,text)',
   $q$select * from public.top_productos('2187-01-01', '2187-12-31')$q$),
  ('public.top_apliques(text,text)',
   $q$select * from public.top_apliques('2187-01-01', '2187-12-31')$q$),
  ('public.resumen_ventas(text,text)',
   $q$select * from public.resumen_ventas('2187-01-01', '2187-12-31')$q$),
  ('public.resumen_ventas_apliques(text,text)',
   $q$select * from public.resumen_ventas_apliques('2187-01-01', '2187-12-31')$q$),
  ('public.inventario_con_ventas(bigint,text,text)',
   $q$select * from public.inventario_con_ventas(1, '2187-01-01', '2187-12-31')$q$);

-- =====================================================================
-- 1. Catálogo: RLS, políticas y privilegios
-- =====================================================================
select tables_are(
  'public', array(select nombre::name from _tablas),
  'public tiene las 16 tablas conocidas (una nueva necesita RLS, su política solo_logueados_* y revisar permisos)'
);
select views_are(
  'public', array['catalogo_apliques_web', 'catalogo_telas_web', 'sucursales_web', 'top_telas_web']::name[],
  'las únicas vistas de public son las *_web de la landing'
);

select is_empty($$
  select c.relname
  from pg_class c
  where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p')
    and not c.relrowsecurity
$$, 'toda tabla de public tiene RLS activado');

select is_empty($$
  select c.relname
  from pg_class c
  where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p')
    and not exists (
      select 1 from pg_policies p
      where p.schemaname = 'public' and p.tablename = c.relname
        and p.policyname = 'solo_logueados_' || c.relname
        and p.permissive = 'PERMISSIVE' and p.cmd = 'ALL'
        and p.roles = array['authenticated']::name[]
        and p.qual = 'true' and p.with_check = 'true')
$$, 'toda tabla tiene su política solo_logueados_<tabla> (FOR ALL TO authenticated USING true WITH CHECK true)');

select is_empty($$
  select tablename, policyname, roles
  from pg_policies
  where schemaname = 'public'
    and (policyname <> 'solo_logueados_' || tablename
         or roles <> array['authenticated']::name[])
$$, 'no quedan otras políticas (acceso_total_*) ni políticas para anon o public');

select is_empty($$
  select c.relname, p.priv
  from pg_class c
  cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER']) p(priv)
  where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p')
    and has_table_privilege('anon', c.oid, p.priv)
$$, 'anon no tiene ningún privilegio sobre las tablas');

select is_empty($$
  select c.relname, p.priv
  from pg_class c
  cross join unnest(array['USAGE', 'SELECT', 'UPDATE']) p(priv)
  where c.relnamespace = 'public'::regnamespace and c.relkind = 'S'
    and case when c.relkind = 'S' then has_sequence_privilege('anon', c.oid, p.priv) end
$$, 'anon no tiene privilegios sobre las secuencias');

select is_empty($$
  select c.relname, p.priv
  from pg_class c
  cross join unnest(array['SELECT', 'INSERT', 'UPDATE']) p(priv)
  where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p')
    and not has_table_privilege('authenticated', c.oid, p.priv)
$$, 'authenticated tiene SELECT, INSERT y UPDATE en todas las tablas');

select is_empty($$
  select c.relname
  from pg_class c
  where c.relnamespace = 'public'::regnamespace and c.relkind = 'S'
    and case when c.relkind = 'S' then not has_sequence_privilege('authenticated', c.oid, 'USAGE') end
$$, 'authenticated puede usar las secuencias de los id identity');

select set_eq($$
  select c.relname::text
  from pg_class c
  cross join unnest(array['anon', 'authenticated']) r(rol)
  where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p', 'v')
    and has_table_privilege(r.rol, c.oid, 'DELETE')
$$, array['detalle_ventas', 'ventas'],
'DELETE físico solo en ventas y detalle_ventas');

select is_empty($$
  select c.relname, r.rol
  from pg_class c
  cross join unnest(array['anon', 'authenticated']) r(rol)
  where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p', 'v')
    and has_table_privilege(r.rol, c.oid, 'TRUNCATE')
$$, 'ni anon ni authenticated pueden TRUNCATE');

select is_empty($$
  select c.relname, r.rol, p.priv
  from pg_class c
  cross join unnest(array['anon', 'authenticated']) r(rol)
  cross join unnest(array['INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER']) p(priv)
  where c.relnamespace = 'public'::regnamespace and c.relkind = 'v'
    and has_table_privilege(r.rol, c.oid, p.priv)
$$, 'las vistas *_web son de solo lectura (corren como su dueño: con escritura serían una puerta a las tablas)');

select is_empty($$
  select c.relname, r.rol
  from pg_class c
  cross join unnest(array['anon', 'authenticated']) r(rol)
  where c.relnamespace = 'public'::regnamespace and c.relkind = 'v'
    and not has_table_privilege(r.rol, c.oid, 'SELECT')
$$, 'anon y authenticated pueden leer todas las vistas *_web');

select set_eq($$
  select p.oid::regprocedure::text
  from pg_proc p
  where p.pronamespace = 'public'::regnamespace and p.proname <> 'rls_auto_enable'
$$, $$ select firma::text from _rpc $$,
'las funciones de public son las 9 RPC conocidas (más el event trigger rls_auto_enable)');

select todo('bug: 20261004000000_solo_usuarios_logueados.sql:40 — el REVOKE ... FROM anon no saca el EXECUTE que PUBLIC tiene por defecto: anon todavía puede ejecutar top_productos, resumen_ventas y resumen_ventas_apliques (no leen datos porque anon no tiene SELECT en las tablas, pero la RPC no debería ser ejecutable)', 1);
select is_empty($$
  select p.oid::regprocedure::text
  from pg_proc p
  where p.pronamespace = 'public'::regnamespace
    and has_function_privilege('anon', p.oid, 'EXECUTE')
$$, 'anon no puede ejecutar ninguna función de public');

select ok(
  has_function_privilege('authenticated', firma, 'EXECUTE'),
  format('authenticated puede ejecutar %s', firma)
) from _rpc;

select ok(
  not has_function_privilege('anon', 'public.rls_auto_enable()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.rls_auto_enable()', 'EXECUTE'),
  'nadie de la API puede ejecutar el event trigger rls_auto_enable'
);

select is_empty($$
  select p.oid::regprocedure::text
  from pg_proc p
  where p.pronamespace = 'public'::regnamespace and p.prosecdef
    and p.proname <> 'rls_auto_enable'
$$, 'las RPC son SECURITY INVOKER: corren con los permisos de quien llama y no saltan RLS');

select is_empty($$
  select p.oid::regprocedure::text
  from pg_proc p
  where p.pronamespace = 'public'::regnamespace
    and not coalesce(p.proconfig, '{}') && array['search_path=public', 'search_path=pg_catalog']
$$, 'toda función de public fija su search_path');

-- =====================================================================
-- 2. anon: nada de tablas ni RPC; solo las vistas *_web
-- =====================================================================
set local role anon;
set local request.jwt.claims = '{"role": "anon"}';

select throws_ok(
  format('select * from public.%I limit 1', nombre), '42501', null,
  format('anon no puede leer %s', nombre)
) from _tablas;

select throws_ok(
  format('insert into public.%I default values', nombre), '42501', null,
  format('anon no puede insertar en %s', nombre)
) from _tablas;

select throws_ok(
  format('update public.%I set %s where false', nombre, cambio), '42501', null,
  format('anon no puede modificar %s', nombre)
) from _tablas;

select throws_ok(
  format('delete from public.%I where false', nombre), '42501', null,
  format('anon no puede borrar en %s', nombre)
) from _tablas;

select throws_ok(
  llamada, '42501', null,
  format('anon recibe permiso denegado al llamar %s', firma)
) from _rpc;

select lives_ok(
  format('select * from public.%I', vista),
  format('anon puede leer %s', vista)
) from unnest(array['sucursales_web', 'top_telas_web', 'catalogo_telas_web', 'catalogo_apliques_web']) vista;

select throws_ok(
  $$ update public.sucursales_web set nombre = nombre where false $$, '42501', null,
  'anon no puede modificar sucursales a través de sucursales_web'
);
select throws_ok(
  $$ insert into public.sucursales_web (nombre) values ('pgTAP intrusa') $$, '42501', null,
  'anon no puede crear sucursales a través de sucursales_web'
);

reset role;

-- =====================================================================
-- 3. authenticated: lee y escribe todo; DELETE solo en ventas y
--    detalle_ventas; TRUNCATE en nada
-- =====================================================================
set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-0000000000a1", "role": "authenticated"}';

select lives_ok($$
  do $do$
  declare
    v_categoria bigint; v_sucursal bigint; v_color bigint; v_aplique bigint;
    v_tela bigint; v_venta bigint; v_venta_aplique bigint; v_produccion bigint;
  begin
    insert into public.categorias (nombre, slug) values ('pgTAP categoría', 'pgtap-categoria')
      returning id into v_categoria;
    insert into public.sucursales (nombre) values ('pgTAP sucursal')
      returning id into v_sucursal;
    insert into public.colores (nombre, hex) values ('pgTAP rojo', '#FF0000')
      returning id into v_color;
    insert into public.apliques (nombre, costo_fabricacion, categoria_id) values ('pgTAP mariposa', 5, v_categoria)
      returning id into v_aplique;
    insert into public.aplique_colores (idaplique, idcolor) values (v_aplique, v_color);
    insert into public.inventario (sucursal_id, aplique_id, color_id, stock) values (v_sucursal, v_aplique, v_color, 3);
    insert into public.telas (nombre, precxmen, categoria_id) values ('pgTAP lino', 10, v_categoria)
      returning id into v_tela;
    insert into public.tela_colores (idtela, idcolor) values (v_tela, v_color);
    insert into public.tela_fotos (idtela, url) values (v_tela, 'https://example.com/pgtap.jpg');
    insert into public.tela_sucursales (idtela, idsucursal) values (v_tela, v_sucursal);
    insert into public.ventas (fecha, idsucursales) values ('2187-03-10T10:00:00.000', v_sucursal)
      returning id into v_venta;
    insert into public.detalle_ventas (nombre, precio, cantidad, total, ganancias, idtelas, idventa)
      values ('pgTAP lino', 10, 1, 10, 2, v_tela, v_venta);
    insert into public.ventas_apliques (fecha, idsucursales) values ('2187-03-10T10:00:00.000', v_sucursal)
      returning id into v_venta_aplique;
    insert into public.detalle_ventas_apliques (idventa, idapliques, idcolor, nombre, precio, cantidad, total, ganancias)
      values (v_venta_aplique, v_aplique, v_color, 'pgTAP mariposa', 8, 1, 8, 3);
    insert into public.producciones (fecha, sucursal_id) values ('2187-03-10', v_sucursal)
      returning id into v_produccion;
    insert into public.detalle_produccion (idproduccion, idaplique, idcolor, cantidad)
      values (v_produccion, v_aplique, v_color, 2);

    insert into pg_temp._ids values
      ('categoria', v_categoria), ('sucursal', v_sucursal), ('color', v_color),
      ('aplique', v_aplique), ('tela', v_tela), ('venta', v_venta),
      ('venta_aplique', v_venta_aplique), ('produccion', v_produccion);
  end
  $do$
$$, 'authenticated puede insertar en las 16 tablas');

-- Sin política, PostgREST devuelve [] en silencio: hay que poder releerlo
select results_eq(
  format('select count(*) from public.%I where %s', nombre, filtro),
  array[1::bigint],
  format('authenticated lee lo que escribió en %s', nombre)
) from _tablas;

select lives_ok(
  format('update public.%I set %s where %s', nombre, cambio, filtro),
  format('authenticated puede modificar %s', nombre)
) from _tablas;

select results_eq(
  format('select count(*) from public.%I where %s and %s', nombre, filtro, cambio),
  array[1::bigint],
  format('el cambio en %s quedó guardado (%s)', nombre, cambio)
) from _tablas;

select throws_ok(
  format('delete from public.%I where %s', nombre, filtro), '42501', null,
  format('authenticated no puede borrar físicamente en %s (baja lógica)', nombre)
) from _tablas
where nombre not in ('ventas', 'detalle_ventas');

select lives_ok(
  $$ delete from public.detalle_ventas where idventa = pg_temp.id('venta') $$,
  'authenticated puede borrar una línea de venta de telas'
);
select is_empty(
  $$ select 1 from public.detalle_ventas where idventa = pg_temp.id('venta') $$,
  'la línea de venta de telas quedó borrada'
);
select lives_ok(
  $$ delete from public.ventas where id = pg_temp.id('venta') $$,
  'authenticated puede borrar una venta de telas'
);
select is_empty(
  $$ select 1 from public.ventas where id = pg_temp.id('venta') $$,
  'la venta de telas quedó borrada'
);

select throws_ok(
  format('truncate public.%I', nombre), '42501', null,
  format('authenticated no puede TRUNCATE %s', nombre)
) from _tablas;

reset role;

select * from finish();
rollback;
