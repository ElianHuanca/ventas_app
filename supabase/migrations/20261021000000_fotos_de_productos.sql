-- =====================================================================
-- Varias fotos por tela y por aplique, guardadas en Supabase Storage.
--
--   * aplique_fotos: igual que tela_fotos (que ya existía, sin ninguna app
--     que la llenara): una fila por foto, baja lógica por activo, orden por
--     id. url es la URL pública del archivo en el bucket.
--   * bucket `fotos` (público: la web y la app leen la URL sin sesión).
--     Subir solo con sesión (rol authenticated), hasta 5 MB y solo imágenes.
--     Sin UPDATE ni DELETE: quitar una foto es activo = false en la tabla
--     (el archivo queda; con ~100 fotos no pesa).
--   * catalogo_telas_web: agrega `fotos` (jsonb, URLs activas por id).
--     catalogo_apliques_web: agrega `foto` (la primera) y `fotos`.
--     Columnas al final (CREATE OR REPLACE VIEW solo deja agregar ahí):
--     ninguna columna existente cambia, la web vieja sigue andando.
--
-- Aditiva. La lee la app Flutter (pantallas Fotos de tela y aplique) y el
-- sitio (galería). Android e iOS no usan fotos.
-- Re-aplicar landing.sql no hace falta: ya trae las mismas vistas.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- aplique_fotos
-- ---------------------------------------------------------------------
CREATE TABLE public.aplique_fotos (
  id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  idaplique bigint NOT NULL REFERENCES public.apliques (id) ON DELETE CASCADE,
  url       text NOT NULL,
  activo    boolean NOT NULL DEFAULT true
);
CREATE INDEX idx_aplique_fotos_aplique ON public.aplique_fotos (idaplique);

ALTER TABLE public.aplique_fotos ENABLE ROW LEVEL SECURITY;
CREATE POLICY solo_logueados_aplique_fotos ON public.aplique_fotos
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Como el resto: leer, insertar y dar de baja; sin DELETE físico
REVOKE ALL ON public.aplique_fotos FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.aplique_fotos TO authenticated;
GRANT USAGE ON SEQUENCE public.aplique_fotos_id_seq TO authenticated;

-- ---------------------------------------------------------------------
-- Bucket `fotos`
-- ---------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('fotos', 'fotos', true, 5 * 1024 * 1024,
        ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS fotos_subir_logueados ON storage.objects;
CREATE POLICY fotos_subir_logueados ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'fotos');

-- ---------------------------------------------------------------------
-- Vistas del catálogo web (copia en landing.sql: si cambia una, ambas)
-- ---------------------------------------------------------------------
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
  fotos.lista->>0 AS foto,
  COALESCE(cols.colores, '[]'::jsonb) AS colores,
  COALESCE(fotos.lista, '[]'::jsonb) AS fotos
FROM public.telas t
LEFT JOIN LATERAL (
  SELECT jsonb_agg(f.url ORDER BY f.id) AS lista
  FROM public.tela_fotos f
  WHERE f.idtela = t.id AND f.activo
) fotos ON TRUE
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
  COALESCE(cols.colores, '[]'::jsonb) AS colores,
  fotos.lista->>0 AS foto,
  COALESCE(fotos.lista, '[]'::jsonb) AS fotos
FROM public.apliques a
LEFT JOIN LATERAL (
  SELECT jsonb_agg(jsonb_build_object('nombre', c.nombre, 'hex', c.hex)
                   ORDER BY lower(c.nombre)) AS colores
  FROM public.aplique_colores ac
  JOIN public.colores c ON c.id = ac.idcolor AND c.activo
  WHERE ac.idaplique = a.id AND ac.activo
) cols ON TRUE
LEFT JOIN LATERAL (
  SELECT jsonb_agg(f.url ORDER BY f.id) AS lista
  FROM public.aplique_fotos f
  WHERE f.idaplique = a.id AND f.activo
) fotos ON TRUE
WHERE a.activo
ORDER BY lower(a.nombre);

GRANT SELECT ON public.catalogo_telas_web, public.catalogo_apliques_web TO anon;

COMMIT;
