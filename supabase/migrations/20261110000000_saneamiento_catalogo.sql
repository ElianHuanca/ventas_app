-- =====================================================================
-- Saneamiento del catálogo (feature specs/001-saneamiento-catalogo)
--
-- 1) categoria_id con DEFAULT (telas → 1 "Telas", apliques → 2 "Apliques") y relleno de nulos:
--    ninguna app manda categoría al crear productos.
-- 2) nombres normalizados en telas, apliques y colores: BEFORE INSERT OR UPDATE OF nombre recorta
--    espacios al borde, colapsa espacios dobles y pone mayúscula inicial. Relleno de los existentes.
-- Aditiva e idempotente: se puede reaplicar sin efecto.
-- =====================================================================
begin;

alter table public.telas    alter column categoria_id set default 1;
alter table public.apliques alter column categoria_id set default 2;
update public.telas    set categoria_id = 1 where categoria_id is null;
update public.apliques set categoria_id = 2 where categoria_id is null;

create or replace function public.normalizar_nombre() returns trigger
language plpgsql
as $$
begin
  if new.nombre is null then
    return new;
  end if;
  new.nombre := regexp_replace(btrim(new.nombre), '\s+', ' ', 'g');
  if new.nombre <> '' then
    new.nombre := upper(left(new.nombre, 1)) || substr(new.nombre, 2);
  end if;
  return new;
end;
$$;
revoke all on function public.normalizar_nombre() from public, anon;
grant execute on function public.normalizar_nombre() to authenticated, service_role;

drop trigger if exists normalizar_nombre on public.telas;
create trigger normalizar_nombre before insert or update of nombre on public.telas
  for each row execute function public.normalizar_nombre();
drop trigger if exists normalizar_nombre on public.apliques;
create trigger normalizar_nombre before insert or update of nombre on public.apliques
  for each row execute function public.normalizar_nombre();
drop trigger if exists normalizar_nombre on public.colores;
create trigger normalizar_nombre before insert or update of nombre on public.colores
  for each row execute function public.normalizar_nombre();

-- relleno: el disparador normaliza al actualizar
update public.telas    set nombre = nombre where nombre <> regexp_replace(btrim(nombre), '\s+', ' ', 'g') or left(nombre, 1) <> upper(left(nombre, 1));
update public.apliques set nombre = nombre where nombre <> regexp_replace(btrim(nombre), '\s+', ' ', 'g') or left(nombre, 1) <> upper(left(nombre, 1));
update public.colores  set nombre = nombre where nombre <> regexp_replace(btrim(nombre), '\s+', ' ', 'g') or left(nombre, 1) <> upper(left(nombre, 1));

commit;