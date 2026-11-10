-- =====================================================================
-- Saneamiento del catálogo (migración 20261110000000_saneamiento_catalogo.sql)
--   * telas/apliques nuevos sin categoría quedan con la de su tipo (1 / 2);
--   * nombres de telas, apliques y colores se normalizan al insertar y al
--     actualizar: espacios al borde, espacios dobles y mayúscula inicial;
--   * un nombre ya limpio no cambia; no quedan filas sin categoría ni
--     nombres sucios.
-- Corre como authenticated (el rol de la app). Rollback al final.
-- =====================================================================
begin;
select plan(10);
set local role authenticated;

insert into public.telas (nombre, precxmen, precxmay, precxrollo, precxcompra, activo)
  values ('  tull   de  prueba ', 10, 9, 8, 7, true);
select is((select categoria_id from public.telas where nombre = 'Tull de prueba'), 1::bigint, 'tela nueva queda en la categoría Telas');
select is((select count(*) from public.telas where nombre = 'Tull de prueba'), 1::bigint, 'nombre de tela recortado, sin dobles espacios y con mayúscula inicial');

insert into public.apliques (nombre, costo_fabricacion, activo) values (' mariposa prueba', 0, true);
select is((select categoria_id from public.apliques where nombre = 'Mariposa prueba'), 2::bigint, 'aplique nuevo queda en la categoría Apliques');

insert into public.colores (nombre, activo) values ('violeta prueba ', true);
select is((select count(*) from public.colores where nombre = 'Violeta prueba'), 1::bigint, 'nombre de color normalizado al insertar');

update public.telas set nombre = 'tull de prueba  ' where nombre = 'Tull de prueba';
select is((select count(*) from public.telas where nombre = 'Tull de prueba'), 1::bigint, 'nombre de tela normalizado al actualizar');

update public.telas set nombre = 'Tull de prueba' where nombre = 'Tull de prueba';
select is((select count(*) from public.telas where nombre = 'Tull de prueba'), 1::bigint, 'un nombre limpio no cambia');

select is((select count(*) from public.telas where categoria_id is null), 0::bigint, 'ninguna tela sin categoría');
select is((select count(*) from public.apliques where categoria_id is null), 0::bigint, 'ningún aplique sin categoría');
select is((select count(*) from public.telas where nombre <> btrim(nombre) or left(nombre, 1) <> upper(left(nombre, 1))), 0::bigint, 'ningún nombre de tela sucio');
select is((select count(*) from public.apliques where nombre <> btrim(nombre) or left(nombre, 1) <> upper(left(nombre, 1))), 0::bigint, 'ningún nombre de aplique sucio');

select * from finish();
rollback;