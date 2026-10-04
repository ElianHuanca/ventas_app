-- =====================================================================
-- Vistas del catálogo web (catalogo_telas_web, catalogo_apliques_web)
--
-- Copia de las vistas que agregó landing.sql después del dump de
-- producción (20260925000000_prod_schema.sql). Va como migración para que
-- `db reset` las cree en local y quede registro de que existen.
--
-- Es CREATE OR REPLACE: re-aplicarla en producción es seguro aunque
-- landing.sql ya las haya creado. landing.sql sigue siendo el archivo que
-- se edita para la web; si cambia una de estas vistas, actualizar ambos.
-- =====================================================================

CREATE OR REPLACE VIEW public.catalogo_telas_web AS
SELECT
  t.id,
  t.nombre,
  t.slug,
  t.descripcion,
  t.ancho,
  NULLIF(t.precxmen,   0) AS precio_metro,
  NULLIF(t.precxmay,   0) AS precio_mayor,
  NULLIF(t.precxrollo, 0) AS precio_rollo,
  foto.url AS foto,
  COALESCE(cols.colores, '[]'::jsonb) AS colores
FROM public.telas t
LEFT JOIN LATERAL (
  SELECT f.url
  FROM public.tela_fotos f
  WHERE f.idtela = t.id AND f.activo
  ORDER BY f.id
  LIMIT 1
) foto ON TRUE
LEFT JOIN LATERAL (
  SELECT jsonb_agg(jsonb_build_object('nombre', c.nombre, 'hex', c.hex)
                   ORDER BY lower(c.nombre)) AS colores
  FROM public.tela_colores tc
  JOIN public.colores c ON c.id = tc.idcolor AND c.activo
  WHERE tc.idtela = t.id AND tc.activo
) cols ON TRUE
WHERE t.activo
ORDER BY lower(t.nombre);

CREATE OR REPLACE VIEW public.catalogo_apliques_web AS
SELECT
  a.id,
  a.nombre,
  a.tamanio,
  a.ancho_cm,
  a.alto_cm,
  COALESCE(cols.colores, '[]'::jsonb) AS colores
FROM public.apliques a
LEFT JOIN LATERAL (
  SELECT jsonb_agg(jsonb_build_object('nombre', c.nombre, 'hex', c.hex)
                   ORDER BY lower(c.nombre)) AS colores
  FROM public.aplique_colores ac
  JOIN public.colores c ON c.id = ac.idcolor AND c.activo
  WHERE ac.idaplique = a.id AND ac.activo
) cols ON TRUE
WHERE a.activo
ORDER BY lower(a.nombre);

GRANT SELECT ON public.catalogo_telas_web    TO anon;
GRANT SELECT ON public.catalogo_apliques_web TO anon;
